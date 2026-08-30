//
//  DiskTreemapView.swift
//  mac_cleaner
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

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Space Lens",
                subtitle: "Visualize usage inside a folder you authorize",
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

                if let current = currentNode {
                    Text(breadcrumb(for: current))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }

                if isBuilding {
                    ProgressView("Building treemap…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let current = currentNode {
                    GeometryReader { geo in
                        let nodes = current.children.isEmpty ? [current] : current.children
                        let rects = TreemapLayout.layout(nodes: nodes, in: geo.size)
                        ZStack(alignment: .topLeading) {
                            ForEach(rects) { rect in
                                Button {
                                    if !rect.node.children.isEmpty || isDirectory(rect.node.url) {
                                        drill(into: rect.node)
                                    } else {
                                        appState.cleaning.reveal(rect.node.url)
                                    }
                                } label: {
                                    ZStack(alignment: .topLeading) {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(color(for: rect.node))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .strokeBorder(AppColors.borderSubtle, lineWidth: 1)
                                            )
                                        if rect.width > 64 && rect.height > 36 {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(rect.node.name)
                                                    .font(AppTypography.captionMedium)
                                                    .foregroundStyle(AppColors.textPrimary)
                                                    .lineLimit(1)
                                                Text(rect.node.sizeLabel)
                                                    .font(AppTypography.micro)
                                                    .foregroundStyle(AppColors.textSecondary)
                                            }
                                            .padding(8)
                                        }
                                    }
                                    .frame(width: rect.width - 2, height: rect.height - 2)
                                }
                                .buttonStyle(.plain)
                                .offset(x: rect.x, y: rect.y)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                            .fill(AppColors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
                                    .strokeBorder(AppColors.border, lineWidth: 1)
                            )
                    )
                } else {
                    EmptyState(
                        title: "Choose a folder to visualize",
                        message: "Space Lens maps disk usage for a folder you grant access to.",
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
        .background(AppColors.background)
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
            appState.activityLog.log(.scan, "Built treemap for \(url.path)")
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

    private func color(for node: TreemapNode) -> Color {
        let palette: [Color] = [
            AppColors.accentMuted,
            AppColors.successMuted,
            AppColors.warningMuted,
            AppColors.infoMuted,
            AppColors.surfaceSecondary
        ]
        let index = abs(node.name.hashValue) % palette.count
        return palette[index]
    }
}
