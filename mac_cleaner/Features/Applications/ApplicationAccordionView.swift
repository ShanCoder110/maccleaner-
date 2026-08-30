//
//  ApplicationAccordionView.swift
//  mac_cleaner
//

import SwiftUI

struct ApplicationAccordionView: View {
    let app: InstalledApp
    @Bindable var model: ApplicationsViewModel

    var body: some View {
        VStack(spacing: 0) {
            SelectableAppCard(isSelected: app.isSelected) {
                model.toggleSelection(app.id)
            } content: {
                HStack(spacing: AppSpacing.md) {
                    SelectionCheckbox(isSelected: model.appSelectionBinding(for: app))

                    Image(nsImage: model.icon(for: app))
                        .resizable()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name)
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(rowMeta)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: AppSpacing.sm)

                    storageBadges

                    Button {
                        model.toggleExpanded(app)
                    } label: {
                        Image(systemName: app.isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                                    .fill(AppColors.surfaceHover)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if app.isExpanded {
                expandedPanel
                    .padding(.top, AppSpacing.xs)
                    .padding(.leading, AppSpacing.xl)
            }
        }
    }

    private var rowMeta: String {
        var parts = ["v\(app.version)", app.locationLabel]
        if let opened = app.lastOpenedLabel {
            parts.append("Opened ~\(opened)")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var storageBadges: some View {
        if let summary = model.summariesByAppID[app.id], summary.lastScanDate != nil {
            VStack(alignment: .trailing, spacing: 2) {
                SizeBadge(value: ByteFormat.string(from: summary.totalDiscoveredSize), emphasis: .accent)
                Text(summary.isCachedEstimate ? "Total (est.)" : "Total discovered")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.textTertiary)
            }
        } else if model.loadingLeftovers.contains(app.id) {
            ProgressView().controlSize(.small)
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                SizeBadge(value: app.sizeLabel, emphasis: .prominent)
                Text("App only")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    private var expandedPanel: some View {
        AppCard(padding: AppSpacing.md, radius: AppRadius.xl, showShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                storageSummaryBlock

                if model.loadingLeftovers.contains(app.id) {
                    ProgressView("Searching authorized folders…")
                } else if let leftovers = model.leftoversByAppID[app.id] {
                    if leftovers.filter({ $0.kind != .appBundle }).isEmpty {
                        emptyLeftoversState
                    } else {
                        leftoverGroups(items: leftovers)
                    }
                }

                HStack {
                    SecondaryButton(title: "Rescan", icon: "arrow.clockwise", size: .compact) {
                        Task { await model.loadLeftovers(for: app, force: true) }
                    }
                    .disabled(model.loadingLeftovers.contains(app.id))
                    Spacer()
                }
            }
        }
    }

    private var storageSummaryBlock: some View {
        let summary = model.summariesByAppID[app.id] ?? .unscanned(appBundleSize: app.byteSize)
        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Storage summary")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            summaryLine("Application", summary.appBundleSize)
            if summary.lastScanDate != nil {
                summaryLine("Related storage found", summary.relatedStorageSize)
                summaryLine("Total discovered storage", summary.totalDiscoveredSize, emphasize: true)
                if let date = summary.lastScanDate {
                    Text(summary.isCachedEstimate
                         ? "Cached estimate · scanned \(date.formatted(date: .abbreviated, time: .shortened))"
                         : "Scanned \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            } else {
                Text("Expand and scan to discover related storage. App size alone is not total storage.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func summaryLine(_ title: String, _ bytes: Int64, emphasize: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(emphasize ? AppTypography.bodyMedium : AppTypography.callout)
                .foregroundStyle(emphasize ? AppColors.textPrimary : AppColors.textSecondary)
            Spacer()
            Text(ByteFormat.string(from: bytes))
                .font(emphasize ? AppTypography.bodyMedium : AppTypography.callout)
                .foregroundStyle(emphasize ? AppColors.accent : AppColors.textPrimary)
        }
    }

    private var emptyLeftoversState: some View {
        let searched = model.searchedFoldersByAppID[app.id] ?? model.grantedFolderTitles
        let missing = model.missingRecommendedKinds

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("No related files were found in the folders currently available to MacCleaner+.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)

            if searched.isEmpty {
                Text("No folders are authorized yet.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            } else {
                Text("Searched: \(searched.joined(separator: ", "))")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }

            if !missing.isEmpty {
                Text("Authorize more folders (like Application Support or Caches) to find leftovers, then rescan.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                SecondaryButton(title: "Manage Permissions", icon: "folder.badge.plus", size: .compact) {
                    model.openManagePermissions()
                }
            }
        }
    }

    private func leftoverGroups(items: [LeftoverItem]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(LeftoverKind.displayOrder, id: \.self) { kind in
                let group = items.filter { $0.kind == kind }
                if !group.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            Text(kind.title)
                                .font(AppTypography.captionMedium)
                                .foregroundStyle(AppColors.textSecondary)
                            Spacer()
                            Text(ByteFormat.string(from: group.reduce(0) { $0 + $1.byteSize }))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }

                        ForEach(group) { item in
                            leftoverRow(item)
                        }
                    }
                }
            }
        }
    }

    private func leftoverRow(_ item: LeftoverItem) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            SelectionCheckbox(isSelected: model.leftoverSelectionBinding(appID: app.id, itemID: item.id))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary)
                Text(item.displayPath)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1)
                    .help(item.displayPath)

                HStack(spacing: AppSpacing.xs) {
                    StatusBadge(title: item.matchConfidence.title, style: item.matchConfidence.badgeStyle)
                    StatusBadge(title: item.safety.title, style: item.safety.badgeStyle)
                    if item.isSharedOrPossiblyShared {
                        StatusBadge(title: "Shared", style: .warning, icon: "person.2")
                    }
                    Button("Why is this here?") {
                        model.whyItem = item
                    }
                    .buttonStyle(.plain)
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.accent)
                }

                if item.isSharedOrPossiblyShared, item.relatedInstalledAppNames.count > 1 {
                    Text("Also may belong to: \(item.relatedInstalledAppNames.dropFirst().joined(separator: ", "))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.warning)
                }
            }

            Spacer(minLength: 0)

            SizeBadge(value: item.sizeLabel)

            IconButton(systemName: "eye", size: 28, iconSize: 11, help: "Quick Look") {
                model.preview(item.url)
            }
            IconButton(systemName: "folder", size: 28, iconSize: 11, help: "Reveal in Finder") {
                model.reveal(item.url)
            }
        }
        .padding(.vertical, 4)
    }
}
