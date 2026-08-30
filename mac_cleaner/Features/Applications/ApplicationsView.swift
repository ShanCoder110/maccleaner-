//
//  ApplicationsView.swift
//  mac_cleaner
//
//  Transparent, confidence-based application storage manager and uninstaller.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

struct ApplicationsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bookmarks: BookmarkStore
    @State private var model = ApplicationsViewModel()

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            ContentToolbar(
                title: "Applications",
                subtitle: "See real storage, understand matches, and choose exactly what moves to Trash",
                searchText: $model.searchText,
                searchPlaceholder: "Search applications"
            )

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FolderAccessBanner()
                controlsRow
                sectionHeader

                if model.isLoading {
                    ProgressView("Loading applications…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.filteredApps.isEmpty {
                    EmptyState(
                        title: model.filterEmptyTitle,
                        message: model.filterEmptyMessage,
                        systemImage: model.filter == .selected ? "checkmark.circle" : (model.filter == .unused ? "clock" : "square.grid.2x2"),
                        primaryActionTitle: model.filter == .all ? "Refresh" : "Show All",
                        primaryAction: {
                            if model.filter == .all {
                                model.reload()
                            } else {
                                model.filter = .all
                            }
                        },
                        secondaryActionTitle: model.filter == .all ? nil : "Refresh",
                        secondaryAction: model.filter == .all ? nil : { model.reload() }
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(model.filteredApps) { app in
                                ApplicationAccordionView(app: app, model: model)
                            }
                        }
                    }
                    .id("\(model.filter.rawValue)-\(model.sort.rawValue)-\(model.unusedThreshold.rawValue)")
                }

                if !model.statusMessage.isEmpty {
                    Text(model.statusMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(AppSpacing.contentInset)
        }
        .background(AppColors.background)
        .onDrop(of: [.fileURL], isTargeted: nil, perform: model.handleDrop)
        .onAppear {
            model.attach(appState)
        }
        .onChange(of: appState.sensitivity) { _, _ in
            model.invalidateScansForScopeChange()
        }
        .onReceive(bookmarks.objectWillChange) { _ in
            DispatchQueue.main.async {
                model.invalidateScansForScopeChange()
            }
        }
        .sheet(isPresented: $model.showConfirmSheet) {
            ApplicationUninstallConfirmSheet(model: model)
        }
        .sheet(isPresented: $model.showResultSheet) {
            if let result = model.resultSummary {
                ApplicationUninstallResultSheet(model: model, result: result)
            }
        }
        .sheet(item: $model.whyItem) { item in
            ApplicationWhySheet(item: item) {
                model.whyItem = nil
            }
        }
    }

    private var controlsRow: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                AppFilterChipGroup(
                    options: AppListFilter.allCases.map { ($0, $0.title) },
                    selection: $model.filter
                )

                Spacer(minLength: 0)

                SecondaryButton(title: "Refresh", icon: "arrow.clockwise", size: .compact) {
                    model.reload()
                }

                PrimaryButton(
                    title: "Uninstall",
                    icon: "trash",
                    isLoading: model.isUninstalling,
                    isDisabled: model.selectedApps.isEmpty,
                    size: .compact
                ) {
                    Task { await model.prepareConfirm() }
                }
            }

            HStack(spacing: AppSpacing.sm) {
                if model.filter == .unused {
                    AppMenuPicker(
                        label: "Unused",
                        options: UnusedThreshold.allCases.map { ($0, $0.title) },
                        selection: $model.unusedThreshold,
                        minWidth: 108
                    )
                    .help("Only apps with a known last-opened date older than this period.")
                }

                AppMenuPicker(
                    label: "Sort",
                    options: AppListSort.allCases.map { ($0, $0.title) },
                    selection: $model.sort,
                    minWidth: 132
                )
                .help("Sort the visible application list.")

                AppMenuPicker(
                    label: "Match",
                    options: LeftoverSensitivity.allCases.map { ($0, $0.title) },
                    selection: $appState.sensitivity,
                    minWidth: 148
                )
                .help(appState.sensitivity.detail)

                Spacer(minLength: 0)
            }

            Text(model.filterHint)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
                .animation(.easeOut(duration: 0.15), value: model.filter)
                .animation(.easeOut(duration: 0.15), value: appState.sensitivity)
        }
    }

    private var sectionHeader: some View {
        SectionHeader(
            title: "Installed Apps",
            subtitle: "\(model.filteredApps.count) apps · expand a row to review related storage"
        ) {
            SizeBadge(
                value: ByteFormat.string(from: model.filteredApps.reduce(0) { $0 + model.totalSize(for: $1) }),
                emphasis: .accent
            )
        }
    }
}
