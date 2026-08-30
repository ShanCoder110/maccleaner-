//
//  DiskTreemapView.swift
//  mac_cleaner
//
//  Space Lens — view-only ranked usage breakdown for an authorized folder.
//

import SwiftUI

struct DiskTreemapView: View {
    @EnvironmentObject private var appState: AppState

    @State private var rootNode: TreemapNode?
    @State private var pathStack: [TreemapNode] = []
    @State private var searchText = ""
    @State private var isBuilding = false
    @State private var statusMessage = ""

    private var currentNode: TreemapNode? {
        pathStack.last ?? rootNode
    }

    private var rankedChildren: [TreemapNode] {
        guard let current = currentNode else { return [] }
        let children = current.children.sorted { $0.byteSize > $1.byteSize }
        guard !searchText.isEmpty else { return children }
        return children.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Space Lens",
                subtitle: "See what uses space inside a folder you authorize",
                searchText: $searchText
            )

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FolderAccessBanner()

                HStack {
                    SecondaryButton(title: "Manage Permissions", icon: "folder.badge.plus", size: .compact) {
                        appState.openManagePermissions()
                    }
                    SecondaryButton(title: "Choose Folder", icon: "folder", size: .compact) {
                        chooseFolder()
                    }
                    if !pathStack.isEmpty {
                        SecondaryButton(title: "Back", icon: "chevron.left", size: .compact) {
                            _ = pathStack.popLast()
                        }
                    }
                    Spacer()
                    if let currentNode {
                        SizeBadge(value: currentNode.sizeLabel, emphasis: .accent)
                    }
                }

                if isBuilding {
                    ProgressView("Analyzing folder…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let current = currentNode {
                    usageContent(for: current)
                } else {
                    EmptyState(
                        title: "Choose a folder to explore",
                        message: "Space Lens shows a clear breakdown of disk usage for any folder you grant access to.",
                        systemImage: "square.3.layers.3d",
                        primaryActionTitle: "Choose Folder",
                        primaryAction: chooseFolder
                    )
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(AppSpacing.contentInset)
        }
        .background(Color.clear)
    }

    @ViewBuilder
    private func usageContent(for current: TreemapNode) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(current.name)
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Text(breadcrumb(for: current))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(2)
            }

            if searchText.isEmpty {
                SpaceLensCompositionBar(
                    parent: current,
                    children: current.children.sorted { $0.byteSize > $1.byteSize }
                )
            }

            SectionHeader(
                title: "Largest items",
                subtitle: rankedChildren.isEmpty
                    ? "No items to show"
                    : "\(rankedChildren.count) item\(rankedChildren.count == 1 ? "" : "s") · sorted by size"
            )

            if rankedChildren.isEmpty {
                Text(searchText.isEmpty ? "This folder has no measurable children." : "No items match your search.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(rankedChildren) { child in
                            SpaceLensUsageRow(
                                node: child,
                                parentBytes: max(current.byteSize, 1),
                                isDirectory: isDirectory(child.url) || !child.children.isEmpty,
                                onActivate: { activate(child) }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func chooseFolder() {
        guard let folder = appState.bookmarks.requestFolderAccess(
            message: "Choose a folder to visualize.",
            suggestedPath: BookmarkStore.realUserHomePath(),
            kind: .custom
        ), let url = appState.bookmarks.startAccess(for: folder.id) else {
            return
        }
        build(from: url)
    }

    private func build(from url: URL) {
        isBuilding = true
        pathStack = []
        Task {
            let node = await ScanTask.detached {
                TreemapBuilder().build(root: url)
            }
            rootNode = node
            isBuilding = false
            statusMessage = "Showing \(node.children.count) top-level items in \(node.name)."
            appState.activityLog.log(.scan, "Space Lens analyzed \(url.path)")
        }
    }

    private func activate(_ node: TreemapNode) {
        if !node.children.isEmpty || isDirectory(node.url) {
            drill(into: node)
        } else {
            appState.cleaning.reveal(node.url)
        }
    }

    private func drill(into node: TreemapNode) {
        if node.children.isEmpty {
            isBuilding = true
            Task {
                let detailed = await ScanTask.detached {
                    TreemapBuilder().build(root: node.url, maxDepth: 1)
                }
                pathStack.append(detailed)
                isBuilding = false
            }
        } else {
            pathStack.append(node)
        }
    }

    private func breadcrumb(for node: TreemapNode) -> String {
        ([rootNode?.name].compactMap { $0 } + pathStack.map(\.name)).joined(separator: " / ")
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return false
        }
        return isDir.boolValue
    }
}

// MARK: - Composition bar

private struct SpaceLensCompositionSegment: Identifiable {
    let id: String
    let name: String
    let byteSize: Int64
    let color: Color
}

private struct SpaceLensCompositionBar: View {
    let parent: TreemapNode
    let children: [TreemapNode]

    private static let maxSegments = 8

    private var segments: [SpaceLensCompositionSegment] {
        let palette = SpaceLensPalette.colors
        let top = Array(children.prefix(Self.maxSegments))
        var result: [SpaceLensCompositionSegment] = top.enumerated().map { index, node in
            SpaceLensCompositionSegment(
                id: node.id.uuidString,
                name: node.name,
                byteSize: node.byteSize,
                color: palette[index % palette.count]
            )
        }
        let shown = top.reduce(Int64(0)) { $0 + $1.byteSize }
        let other = max(parent.byteSize - shown, 0)
        if other > 0, children.count > Self.maxSegments || shown < parent.byteSize {
            result.append(
                SpaceLensCompositionSegment(
                    id: "other",
                    name: "Other",
                    byteSize: other,
                    color: AppColors.textTertiary.opacity(0.45)
                )
            )
        }
        return result.filter { $0.byteSize > 0 }
    }

    private var total: Int64 {
        max(parent.byteSize, segments.reduce(0) { $0 + $1.byteSize }, 1)
    }

    var body: some View {
        AppCard(padding: AppSpacing.lg, showShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Usage mix")
                        .font(AppTypography.calloutMedium)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text(parent.sizeLabel)
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.textSecondary)
                        .monospacedDigit()
                }

                GeometryReader { geo in
                    let gap: CGFloat = 2
                    let gaps = CGFloat(max(segments.count - 1, 0)) * gap
                    let usable = max(geo.size.width - gaps, 1)
                    HStack(spacing: gap) {
                        ForEach(segments) { segment in
                            let width = max(3, usable * CGFloat(segment.byteSize) / CGFloat(total))
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(segment.color)
                                .frame(width: width)
                                .help("\(segment.name) · \(ByteFormat.string(from: segment.byteSize))")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                .frame(height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppColors.progressTrack)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                FlowLegend(segments: segments, total: total)
            }
        }
    }
}

private struct FlowLegend: View {
    let segments: [SpaceLensCompositionSegment]
    let total: Int64

    var body: some View {
        FlexibleLegendLayout(spacing: AppSpacing.md) {
            ForEach(segments) { segment in
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(segment.color)
                        .frame(width: 8, height: 8)
                    Text(segment.name)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                    Text(percentLabel(for: segment.byteSize))
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.textTertiary)
                        .monospacedDigit()
                }
            }
        }
    }

    private func percentLabel(for bytes: Int64) -> String {
        let pct = Double(bytes) / Double(max(total, 1)) * 100
        if pct >= 10 {
            return String(format: "%.0f%%", pct)
        }
        return String(format: "%.1f%%", pct)
    }
}

/// Simple wrapping HStack for legend chips without pulling in a layout package.
private struct FlexibleLegendLayout: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var height: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                height = y
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            height = max(height, y + rowHeight)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

// MARK: - Ranked row

private struct SpaceLensUsageRow: View {
    let node: TreemapNode
    let parentBytes: Int64
    let isDirectory: Bool
    let onActivate: () -> Void

    @State private var isHovered = false

    private var fraction: Double {
        min(max(Double(node.byteSize) / Double(max(parentBytes, 1)), 0), 1)
    }

    private var percentLabel: String {
        let pct = fraction * 100
        if pct >= 10 {
            return String(format: "%.0f%%", pct)
        }
        if pct >= 1 {
            return String(format: "%.1f%%", pct)
        }
        return "<1%"
    }

    var body: some View {
        Button(action: onActivate) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: isDirectory ? "folder.fill" : "doc.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isDirectory ? AppColors.accent : AppColors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .fill(isDirectory ? AppColors.accentMuted : AppColors.surfaceSecondary)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.name)
                            .font(AppTypography.calloutMedium)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                        Text(isDirectory ? "Folder · click to open" : "File · reveal in Finder")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    Spacer(minLength: AppSpacing.sm)

                    Text(percentLabel)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .monospacedDigit()
                        .frame(minWidth: 36, alignment: .trailing)

                    SizeBadge(value: node.sizeLabel, emphasis: .regular)

                    Image(systemName: isDirectory ? "chevron.right" : "arrow.right.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(AppColors.progressTrack)
                        Capsule(style: .continuous)
                            .fill(SpaceLensPalette.color(for: node.name))
                            .frame(width: max(4, geo.size.width * fraction))
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .fill(isHovered ? AppColors.surfaceSecondary : AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .strokeBorder(AppColors.border, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

private enum SpaceLensPalette {
    static let colors: [Color] = [
        AppColors.accent,
        AppColors.success,
        AppColors.warning,
        AppColors.info,
        Color(hex: 0x8B5CF6),
        Color(hex: 0x14B8A6),
        Color(hex: 0xF472B6),
        Color(hex: 0x64748B)
    ]

    static func color(for name: String) -> Color {
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
}
