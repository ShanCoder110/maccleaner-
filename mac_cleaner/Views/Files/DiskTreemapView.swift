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
                        Text(currentNode.sizeLabel)
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.accent)
                            .monospacedDigit()
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
        let slices = SpaceLensSlices.make(
            children: rankedChildren,
            parentBytes: current.byteSize,
            collapseRemainder: rankedChildren.count > SpaceLensSlices.maxNamed + 1,
            isDirectory: { isDirectory($0) }
        )

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

            if searchText.isEmpty, !slices.isEmpty {
                SpaceLensCompositionBar(slices: slices, totalBytes: current.byteSize)
            }

            SectionHeader(
                title: "Largest items",
                subtitle: rankedChildren.isEmpty
                    ? "No items to show"
                    : "\(rankedChildren.count) item\(rankedChildren.count == 1 ? "" : "s") · sorted by size"
            )

            if slices.isEmpty {
                Text(searchText.isEmpty ? "This folder has no measurable children." : "No items match your search.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                SpaceLensBentoGrid(slices: slices, totalBytes: max(current.byteSize, 1)) { slice in
                    guard let node = slice.node else { return }
                    activate(node)
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

// MARK: - Shared slices

private struct SpaceLensSlice: Identifiable {
    let id: String
    let name: String
    let byteSize: Int64
    let color: Color
    let node: TreemapNode?
    let isDirectory: Bool
}

private enum SpaceLensSlices {
    static let maxNamed = 7

    static func make(
        children: [TreemapNode],
        parentBytes: Int64,
        collapseRemainder: Bool,
        isDirectory: (URL) -> Bool
    ) -> [SpaceLensSlice] {
        let sorted = children.sorted { $0.byteSize > $1.byteSize }
        let palette = SpaceLensPalette.colors
        let shouldCollapse = collapseRemainder && sorted.count > maxNamed + 1
        let named = shouldCollapse ? Array(sorted.prefix(maxNamed)) : sorted

        var slices: [SpaceLensSlice] = named.enumerated().map { index, node in
            SpaceLensSlice(
                id: node.id.uuidString,
                name: node.name,
                byteSize: node.byteSize,
                color: palette[index % palette.count],
                node: node,
                isDirectory: isDirectory(node.url) || !node.children.isEmpty
            )
        }

        if shouldCollapse {
            let shown = named.reduce(Int64(0)) { $0 + $1.byteSize }
            let other = max(parentBytes - shown, sorted.dropFirst(maxNamed).reduce(0) { $0 + $1.byteSize })
            if other > 0 {
                slices.append(
                    SpaceLensSlice(
                        id: "other",
                        name: "Other",
                        byteSize: other,
                        color: SpaceLensPalette.other,
                        node: nil,
                        isDirectory: false
                    )
                )
            }
        }

        return slices.filter { $0.byteSize > 0 }
    }
}

// MARK: - Composition bar

private struct SpaceLensCompositionBar: View {
    let slices: [SpaceLensSlice]
    let totalBytes: Int64

    private var total: Int64 {
        max(totalBytes, slices.reduce(0) { $0 + $1.byteSize }, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Spacer()
                Text(ByteFormat.string(from: totalBytes))
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(slices) { slice in
                        let width = max(4, geo.size.width * CGFloat(slice.byteSize) / CGFloat(total))
                        Rectangle()
                            .fill(slice.color)
                            .frame(width: width)
                            .help("\(slice.name) · \(ByteFormat.string(from: slice.byteSize))")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(height: 12)
            .clipShape(Capsule(style: .continuous))

            FlowLegend(slices: slices, total: total)
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                .fill(AppColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1)
        )
    }
}

private struct FlowLegend: View {
    let slices: [SpaceLensSlice]
    let total: Int64

    var body: some View {
        FlexibleLegendLayout(spacing: AppSpacing.md) {
            ForEach(slices) { slice in
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 8, height: 8)
                    Text(slice.name)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                    Text(SpaceLensPalette.percentLabel(bytes: slice.byteSize, total: total))
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.textTertiary)
                        .monospacedDigit()
                }
            }
        }
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

// MARK: - Bento treemap

private struct SpaceLensBentoGrid: View {
    let slices: [SpaceLensSlice]
    let totalBytes: Int64
    var onActivate: (SpaceLensSlice) -> Void

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 10
            let bounds = CGRect(origin: .zero, size: geo.size)
            let weights = slices.map { Double($0.byteSize) }
            let rects = SquarifiedTreemap.layout(weights: weights, in: bounds)

            ZStack(alignment: .topLeading) {
                ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                    let raw = index < rects.count ? rects[index] : .zero
                    let frame = raw.insetBy(dx: gap / 2, dy: gap / 2)
                    if frame.width > 8, frame.height > 8 {
                        SpaceLensBentoTile(
                            slice: slice,
                            totalBytes: totalBytes,
                            onActivate: { onActivate(slice) }
                        )
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                    }
                }
            }
        }
    }
}

private struct SpaceLensBentoTile: View {
    let slice: SpaceLensSlice
    let totalBytes: Int64
    var onActivate: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onActivate) {
            GeometryReader { geo in
                let compact = geo.size.width < 118 || geo.size.height < 72
                let tiny = geo.size.width < 88 || geo.size.height < 56

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                        .fill(tileGradient)
                    RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        if !tiny {
                            Image(systemName: slice.isDirectory || slice.node == nil ? "folder.fill" : "doc.fill")
                                .font(.system(size: compact ? 14 : 18, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                        }

                        Spacer(minLength: 0)

                        Text(slice.name)
                            .font(compact ? AppTypography.calloutMedium : AppTypography.headline)
                            .foregroundStyle(.white)
                            .lineLimit(compact ? 1 : 2)

                        if !tiny {
                            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                                Text(ByteFormat.string(from: slice.byteSize))
                                    .font(compact ? AppTypography.captionMedium : AppTypography.title2)
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                                Text(SpaceLensPalette.percentLabel(bytes: slice.byteSize, total: totalBytes))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .monospacedDigit()
                            }
                        }
                    }
                    .padding(compact ? AppSpacing.sm : AppSpacing.md)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                    .strokeBorder(Color.white.opacity(isHovered ? 0.28 : 0.12), lineWidth: 1)
            )
            .shadow(color: slice.color.opacity(isHovered ? 0.38 : 0.22), radius: isHovered ? 16 : 10, y: 6)
            .scaleEffect(isHovered ? 1.015 : 1)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(slice.node == nil)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
        .help("\(slice.name) · \(ByteFormat.string(from: slice.byteSize))")
    }

    private var tileGradient: LinearGradient {
        LinearGradient(
            colors: [
                slice.color.opacity(0.98),
                slice.color.opacity(0.78)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Squarified treemap

private enum SquarifiedTreemap {
    static func layout(weights: [Double], in bounds: CGRect) -> [CGRect] {
        guard !weights.isEmpty else { return [] }
        let total = weights.reduce(0, +)
        guard total > 0, bounds.width > 1, bounds.height > 1 else {
            return Array(repeating: .zero, count: weights.count)
        }

        var remaining = weights.map { $0 / total * Double(bounds.width) * Double(bounds.height) }
        var rects: [CGRect] = []
        var space = bounds

        while !remaining.isEmpty {
            let vertical = space.width >= space.height
            let length = Double(vertical ? space.height : space.width)
            var rowCount = 1
            while rowCount < remaining.count,
                  worstAspect(remaining, count: rowCount, length: length)
                    >= worstAspect(remaining, count: rowCount + 1, length: length) {
                rowCount += 1
            }

            let row = Array(remaining.prefix(rowCount))
            remaining.removeFirst(rowCount)
            let rowArea = row.reduce(0, +)
            let leftover = remaining.reduce(0, +) + rowArea
            let longSide = Double(vertical ? space.width : space.height)
            let thickness = CGFloat(leftover > 0 ? (rowArea / leftover) * longSide : longSide)

            var cursor: CGFloat = 0
            for area in row {
                let share = rowArea > 0 ? CGFloat(area / rowArea) : 0
                let rect: CGRect
                if vertical {
                    let height = space.height * share
                    rect = CGRect(x: space.minX, y: space.minY + cursor, width: thickness, height: height)
                    cursor += height
                } else {
                    let width = space.width * share
                    rect = CGRect(x: space.minX + cursor, y: space.minY, width: width, height: thickness)
                    cursor += width
                }
                rects.append(rect)
            }

            if vertical {
                space = CGRect(
                    x: space.minX + thickness,
                    y: space.minY,
                    width: max(space.width - thickness, 0),
                    height: space.height
                )
            } else {
                space = CGRect(
                    x: space.minX,
                    y: space.minY + thickness,
                    width: space.width,
                    height: max(space.height - thickness, 0)
                )
            }
        }

        return rects
    }

    private static func worstAspect(_ areas: [Double], count: Int, length: Double) -> Double {
        let row = areas.prefix(count)
        let sum = row.reduce(0, +)
        guard let minArea = row.min(), let maxArea = row.max(), sum > 0, length > 0 else {
            return .greatestFiniteMagnitude
        }
        let side = length
        return max((side * side * maxArea) / (sum * sum), (sum * sum) / (side * side * minArea))
    }
}

private enum SpaceLensPalette {
    static let colors: [Color] = [
        Color(hex: 0x4A7DFF),
        Color(hex: 0x34C77B),
        Color(hex: 0xF0A03A),
        Color(hex: 0x8B5CF6),
        Color(hex: 0xF472B6),
        Color(hex: 0x22D3EE),
        Color(hex: 0x60A5FA)
    ]

    static let other = Color(hex: 0x64748B)

    static func percentLabel(bytes: Int64, total: Int64) -> String {
        let pct = Double(bytes) / Double(max(total, 1)) * 100
        if pct >= 10 {
            return String(format: "%.0f%%", pct)
        }
        if pct >= 1 {
            return String(format: "%.1f%%", pct)
        }
        return "<1%"
    }
}
