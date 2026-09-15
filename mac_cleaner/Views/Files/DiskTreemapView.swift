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
        let children = rankedChildren
        let totalBytes = max(current.byteSize, children.reduce(Int64(0)) { $0 + $1.byteSize }, 1)
        let slices = SpaceLensSlices.make(
            children: children,
            parentBytes: totalBytes,
            isDirectory: { isDirectory($0) }
        )
        let layoutMode = SpaceLensLayout.mode(for: children, totalBytes: totalBytes)

        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(current.name)
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                breadcrumbTrail
            }

            if searchText.isEmpty, !slices.isEmpty {
                SpaceLensCompositionBar(slices: slices, totalBytes: totalBytes)
            }

            SectionHeader(
                title: "Largest items",
                subtitle: children.isEmpty
                    ? "No items to show"
                    : layoutMode == .rankedList
                        ? "\(children.count) items · ranked list (one folder dominates)"
                        : "\(children.count) items · sorted by size"
            )

            if children.isEmpty {
                Text(searchText.isEmpty ? "This folder has no measurable children." : "No items match your search.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if layoutMode == .rankedList {
                SpaceLensRankedBrowser(
                    children: children,
                    totalBytes: totalBytes,
                    isDirectory: isDirectory,
                    onOpen: activate,
                    onReveal: { appState.cleaning.reveal($0.url) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SpaceLensBentoGrid(
                    slices: SpaceLensSlices.make(
                        children: children,
                        parentBytes: totalBytes,
                        softenDominance: true,
                        isDirectory: { isDirectory($0) }
                    ),
                    totalBytes: totalBytes
                ) { slice in
                    guard let node = slice.node else { return }
                    activate(node)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var breadcrumbTrail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                if let root = rootNode {
                    breadcrumbChip(title: root.name, isCurrent: pathStack.isEmpty) {
                        pathStack.removeAll()
                    }
                }
                ForEach(Array(pathStack.enumerated()), id: \.element.id) { index, node in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                    breadcrumbChip(title: node.name, isCurrent: index == pathStack.count - 1) {
                        pathStack = Array(pathStack.prefix(index + 1))
                    }
                }
            }
        }
    }

    private func breadcrumbChip(title: String, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.captionMedium)
                .foregroundStyle(isCurrent ? AppColors.textPrimary : AppColors.accent)
                .lineLimit(1)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(isCurrent ? AppColors.controlFillSecondary : AppColors.accentMuted)
                )
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
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

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return false
        }
        return isDir.boolValue
    }
}

// MARK: - Layout mode

private enum SpaceLensLayout {
    case bento
    case rankedList

    /// When one child owns most of the space, a proportional treemap collapses
    /// everything else into unusable slivers — switch to a ranked browser.
    static func mode(for children: [TreemapNode], totalBytes: Int64) -> SpaceLensLayout {
        guard let top = children.first, totalBytes > 0 else { return .rankedList }
        let share = Double(top.byteSize) / Double(totalBytes)
        if share >= 0.55 || children.count > 14 {
            return .rankedList
        }
        return .bento
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
    /// Visual weight used by the bento (may be softened vs true size).
    var visualBytes: Int64
}

private enum SpaceLensSlices {
    static let maxNamed = 8

    static func make(
        children: [TreemapNode],
        parentBytes: Int64,
        softenDominance: Bool = false,
        isDirectory: (URL) -> Bool
    ) -> [SpaceLensSlice] {
        let sorted = children.sorted { $0.byteSize > $1.byteSize }
        let palette = SpaceLensPalette.colors
        let shouldCollapse = sorted.count > maxNamed + 1
        let named = shouldCollapse ? Array(sorted.prefix(maxNamed)) : sorted

        var slices: [SpaceLensSlice] = named.enumerated().map { index, node in
            SpaceLensSlice(
                id: node.id.uuidString,
                name: node.name,
                byteSize: node.byteSize,
                color: palette[index % palette.count],
                node: node,
                isDirectory: isDirectory(node.url) || !node.children.isEmpty,
                visualBytes: node.byteSize
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
                        isDirectory: false,
                        visualBytes: other
                    )
                )
            }
        }

        slices = slices.filter { $0.byteSize > 0 }

        if softenDominance {
            slices = applyVisualFloor(to: slices)
        }

        return slices
    }

    /// Guarantee each tile at least ~6% visual area so small folders stay clickable.
    private static func applyVisualFloor(to slices: [SpaceLensSlice]) -> [SpaceLensSlice] {
        guard slices.count > 1 else { return slices }
        let total = Double(slices.reduce(Int64(0)) { $0 + $1.byteSize })
        guard total > 0 else { return slices }

        let floor = 0.06
        var shares = slices.map { max(Double($0.byteSize) / total, floor) }
        let sum = shares.reduce(0, +)
        shares = shares.map { $0 / sum }

        return zip(slices, shares).map { slice, share in
            var copy = slice
            copy.visualBytes = Int64((share * total).rounded())
            return copy
        }
    }
}

// MARK: - Ranked browser (dominant-folder friendly)

private struct SpaceLensRankedBrowser: View {
    let children: [TreemapNode]
    let totalBytes: Int64
    var isDirectory: (URL) -> Bool
    var onOpen: (TreemapNode) -> Void
    var onReveal: (TreemapNode) -> Void

    var body: some View {
        let palette = SpaceLensPalette.colors
        let top = children.first

        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if let top, Double(top.byteSize) / Double(max(totalBytes, 1)) >= 0.45 {
                    dominantHero(top, color: palette[0])
                }

                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(Array(children.enumerated()), id: \.element.id) { index, node in
                        rankedRow(
                            node,
                            color: palette[index % palette.count],
                            isHeroDuplicate: top?.id == node.id && Double(top?.byteSize ?? 0) / Double(max(totalBytes, 1)) >= 0.45
                        )
                    }
                }
            }
        }
    }

    private func dominantHero(_ node: TreemapNode, color: Color) -> some View {
        let directory = isDirectory(node.url) || !node.children.isEmpty
        return Button {
            onOpen(node)
        } label: {
            HStack(spacing: AppSpacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: directory ? "folder.fill" : "doc.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(directory ? "Largest folder" : "Largest item")
                        .font(AppTypography.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(node.name)
                        .font(AppTypography.title2)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(ByteFormat.string(from: node.byteSize)) · \(SpaceLensPalette.percentLabel(bytes: node.byteSize, total: totalBytes)) of this folder")
                        .font(AppTypography.callout)
                        .foregroundStyle(.white.opacity(0.85))
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(directory ? "Open" : "Reveal")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(.white)
                    Image(systemName: directory ? "chevron.right.circle.fill" : "arrow.up.right.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                }
            }
            .padding(AppSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.95), color.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(directory ? "Open \(node.name) to see what’s inside" : "Reveal \(node.name) in Finder")
    }

    private func rankedRow(_ node: TreemapNode, color: Color, isHeroDuplicate: Bool) -> some View {
        let directory = isDirectory(node.url) || !node.children.isEmpty
        let share = CGFloat(Double(node.byteSize) / Double(max(totalBytes, 1)))

        return Button {
            onOpen(node)
        } label: {
            HStack(spacing: AppSpacing.md) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color)
                    .frame(width: 4, height: 36)

                Image(systemName: directory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(node.name)
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: AppSpacing.sm)
                        Text(ByteFormat.string(from: node.byteSize))
                            .font(AppTypography.calloutMedium)
                            .foregroundStyle(AppColors.textPrimary)
                            .monospacedDigit()
                        Text(SpaceLensPalette.percentLabel(bytes: node.byteSize, total: totalBytes))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(AppColors.progressTrack)
                            Capsule(style: .continuous)
                                .fill(color.opacity(0.9))
                                .frame(width: max(6, geo.size.width * share))
                        }
                    }
                    .frame(height: 6)
                }

                if directory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                } else {
                    IconButton(systemName: "folder", size: 28, iconSize: 11) {
                        onReveal(node)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .fill(isHeroDuplicate ? AppColors.accentMuted.opacity(0.35) : AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .strokeBorder(AppColors.border, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
        }
        .buttonStyle(.plain)
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
                Text("Breakdown")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.textTertiary)
                Spacer()
                Text(ByteFormat.string(from: totalBytes))
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(slices) { slice in
                        // Floor each segment so tiny items remain visible in the bar.
                        let raw = geo.size.width * CGFloat(slice.byteSize) / CGFloat(total)
                        let width = max(slices.count > 12 ? 3 : 5, raw)
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

// MARK: - Bento treemap (balanced folders)

private struct SpaceLensBentoGrid: View {
    let slices: [SpaceLensSlice]
    let totalBytes: Int64
    var onActivate: (SpaceLensSlice) -> Void

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 10
            let bounds = CGRect(origin: .zero, size: geo.size)
            let weights = slices.map { Double(max($0.visualBytes, 1)) }
            let rects = SquarifiedTreemap.layout(weights: weights, in: bounds)

            ZStack(alignment: .topLeading) {
                ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                    let raw = index < rects.count ? rects[index] : .zero
                    let frame = raw.insetBy(dx: gap / 2, dy: gap / 2)
                    if frame.width > 10, frame.height > 10 {
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
