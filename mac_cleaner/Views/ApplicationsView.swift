//
//  ApplicationsView.swift
//  mac_cleaner
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ApplicationsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var apps: [InstalledApp] = []
    @State private var leftoversByAppID: [String: [LeftoverItem]] = [:]
    @State private var loadingLeftovers: Set<String> = []
    @State private var searchText = ""
    @State private var filter = "All"
    @State private var isLoading = false
    @State private var isUninstalling = false
    @State private var confirmUninstall = false
    @State private var progress: Double = 0
    @State private var statusMessage = ""

    private let inventory = AppInventoryService()

    private var filteredApps: [InstalledApp] {
        apps.filter { app in
            let matchesSearch = searchText.isEmpty
                || app.name.localizedCaseInsensitiveContains(searchText)
                || app.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            let matchesFilter: Bool = {
                switch filter {
                case "Selected": return app.isSelected
                case "Large": return app.byteSize >= 500 * 1024 * 1024
                default: return true
                }
            }()
            return matchesSearch && matchesFilter && !app.isSystemApp
        }
    }

    private var selectedApps: [InstalledApp] {
        apps.filter(\.isSelected)
    }

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Applications",
                subtitle: "Uninstall apps and related files in folders you authorized",
                searchText: $searchText,
                searchPlaceholder: "Search applications"
            )

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FolderAccessBanner()

                HStack {
                    AppSegmentedControl(
                        options: [("All", "All"), ("Selected", "Selected"), ("Large", "Large")],
                        selection: $filter
                    )

                    Picker("Sensitivity", selection: $appState.sensitivity) {
                        ForEach(LeftoverSensitivity.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)

                    Spacer()

                    SecondaryButton(title: "Refresh", icon: "arrow.clockwise", size: .compact) {
                        reload()
                    }

                    PrimaryButton(
                        title: "Uninstall",
                        icon: "trash",
                        isLoading: isUninstalling,
                        isDisabled: selectedApps.isEmpty,
                        size: .compact
                    ) {
                        confirmUninstall = true
                    }
                }

                SectionHeader(
                    title: "Installed Apps",
                    subtitle: "\(filteredApps.count) apps · expand a row to review related files"
                ) {
                    SizeBadge(
                        value: ByteFormat.string(from: filteredApps.reduce(0) { $0 + $1.byteSize }),
                        emphasis: .accent
                    )
                }

                if isLoading {
                    ProgressView("Loading applications…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredApps.isEmpty {
                    EmptyState(
                        title: "No applications found",
                        message: "Drop an app here or refresh the list from /Applications.",
                        systemImage: "square.grid.2x2",
                        primaryActionTitle: "Refresh",
                        primaryAction: reload
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(filteredApps) { app in
                                appAccordion(app)
                            }
                        }
                    }
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
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
        .onAppear {
            DispatchQueue.main.async {
                reload()
            }
        }
        .confirmationDialog(
            "Move selected apps and related files to Trash?",
            isPresented: $confirmUninstall,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                Task { await uninstallSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only the app bundles and leftover files you selected will be moved to Trash. You can restore them from Trash if needed.")
        }
    }

    private func appAccordion(_ app: InstalledApp) -> some View {
        let bindingSelected = binding(for: app)
        return VStack(spacing: 0) {
            SelectableAppCard(isSelected: app.isSelected) {
                toggleSelection(app.id)
            } content: {
                HStack(spacing: AppSpacing.md) {
                    SelectionCheckbox(isSelected: bindingSelected)

                    Image(nsImage: inventory.icon(for: app))
                        .resizable()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name)
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.textPrimary)
                        Text("\(app.version) · \(app.bundleIdentifier)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    leftoverSummary(for: app)
                    SizeBadge(value: app.sizeLabel, emphasis: .prominent)

                    Button {
                        toggleExpanded(app)
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
                leftoverPanel(for: app)
                    .padding(.top, AppSpacing.xs)
                    .padding(.leading, AppSpacing.xl)
            }
        }
    }

    @ViewBuilder
    private func leftoverSummary(for app: InstalledApp) -> some View {
        if loadingLeftovers.contains(app.id) {
            ProgressView().controlSize(.small)
        } else if let leftovers = leftoversByAppID[app.id] {
            SizeBadge(
                value: ByteFormat.string(from: leftovers.reduce(0) { $0 + $1.byteSize }),
                emphasis: .accent
            )
        } else {
            Text("—")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
                .frame(width: 28)
        }
    }

    private func leftoverPanel(for app: InstalledApp) -> some View {
        AppCard(padding: AppSpacing.md, radius: AppRadius.xl, showShadow: false) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if loadingLeftovers.contains(app.id) {
                    ProgressView("Searching authorized folders…")
                } else if let leftovers = leftoversByAppID[app.id] {
                    if leftovers.count <= 1 {
                        Text("No related files found in granted folders. Add Application Support, Caches, or Preferences access to find more.")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        ForEach(bindingLeftovers(for: app.id)) { $item in
                            HStack(spacing: AppSpacing.sm) {
                                SelectionCheckbox(isSelected: $item.isSelected)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(AppTypography.bodyMedium)
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text(item.displayPath)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textTertiary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                StatusBadge(title: item.kind.title, style: item.kind.badgeStyle)
                                if item.isSensitive {
                                    StatusBadge(title: "Review", style: .warning)
                                }
                                SizeBadge(value: item.sizeLabel)
                                IconButton(systemName: "folder", size: 28, iconSize: 11, help: "Reveal in Finder") {
                                    appState.cleaning.reveal(item.url)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func binding(for app: InstalledApp) -> Binding<Bool> {
        Binding(
            get: { apps.first(where: { $0.id == app.id })?.isSelected ?? false },
            set: { newValue in
                if let index = apps.firstIndex(where: { $0.id == app.id }) {
                    apps[index].isSelected = newValue
                }
            }
        )
    }

    private func bindingLeftovers(for appID: String) -> Binding<[LeftoverItem]> {
        Binding(
            get: { leftoversByAppID[appID] ?? [] },
            set: { leftoversByAppID[appID] = $0 }
        )
    }

    private func toggleSelection(_ id: String) {
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return }
        apps[index].isSelected.toggle()
    }

    private func toggleExpanded(_ app: InstalledApp) {
        guard let index = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[index].isExpanded.toggle()
        if apps[index].isExpanded {
            Task { await loadLeftovers(for: apps[index]) }
        }
    }

    private func reload() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = inventory.loadInstalledApps()
            DispatchQueue.main.async {
                apps = loaded
                isLoading = false
            }
        }
    }

    private func loadLeftovers(for app: InstalledApp) async {
        if leftoversByAppID[app.id] != nil { return }
        loadingLeftovers.insert(app.id)
        let sensitivity = appState.sensitivity
        let finder = LeftoverFinderService(bookmarks: appState.bookmarks)
        let result = await Task.detached(priority: .userInitiated) {
            finder.findLeftovers(for: app, sensitivity: sensitivity)
        }.value
        leftoversByAppID[app.id] = result
        loadingLeftovers.remove(app.id)
        appState.activityLog.log(.scan, "Found \(result.count) related items for \(app.name)")
    }

    private func uninstallSelected() async {
        isUninstalling = true
        defer { isUninstalling = false }

        var urls: [URL] = []
        for app in selectedApps {
            if leftoversByAppID[app.id] == nil {
                await loadLeftovers(for: app)
            }
            let leftovers = leftoversByAppID[app.id] ?? [
                LeftoverItem(url: app.path, kind: .appBundle, byteSize: app.byteSize)
            ]
            urls.append(contentsOf: leftovers.filter(\.isSelected).map(\.url))
        }

        let result = await appState.cleaning.trash(urls: urls) { value in
            progress = value
        }

        statusMessage = "Moved \(result.trashedCount) items to Trash (\(ByteFormat.string(from: result.freedBytes)))."
        if !result.errors.isEmpty {
            statusMessage += " \(result.errors.count) items could not be removed."
        }
        leftoversByAppID.removeAll()
        reload()
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { object, _ in
                guard let url = object as? URL, url.pathExtension == "app" else { return }
                DispatchQueue.main.async {
                    if let installed = inventory.makeApp(from: url) {
                        if let index = apps.firstIndex(where: { $0.id == installed.id }) {
                            apps[index].isSelected = true
                            apps[index].isExpanded = true
                            Task { await loadLeftovers(for: apps[index]) }
                        } else {
                            var app = installed
                            app.isSelected = true
                            app.isExpanded = true
                            apps.insert(app, at: 0)
                            Task { await loadLeftovers(for: app) }
                        }
                        statusMessage = "Ready to review \(installed.name)."
                    }
                }
            }
        }
        return true
    }
}
