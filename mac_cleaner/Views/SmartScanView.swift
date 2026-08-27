//
//  SmartScanView.swift
//  mac_cleaner
//

import SwiftUI
import AppKit

struct SmartScanView: View {
    @EnvironmentObject private var appState: AppState

    @State private var searchText = ""
    @State private var confirmCleanJunk = false
    @State private var isCleaningJunk = false
    @State private var statusMessage = ""

    private var session: ScanSessionStore { appState.scanSession }

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Smart Scan",
                subtitle: "One-click overview of storage opportunities you authorized",
                searchText: $searchText
            )

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                    FolderAccessBanner()
                    hero
                    if session.hasResults {
                        junkCard
                    }
                    categoriesGrid
                    tipsCard
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(AppSpacing.contentInset)
            }
        }
        .background(AppColors.background)
        .onAppear {
            DispatchQueue.main.async {
                appState.refreshDiskStats()
            }
        }
        .confirmationDialog(
            "Move \(session.junkItemCount) junk items (\(ByteFormat.string(from: session.junkBytes))) to Trash?",
            isPresented: $confirmCleanJunk,
            titleVisibility: .visible
        ) {
            Button("Clean Junk", role: .destructive) {
                Task { await cleanJunk() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var hero: some View {
        AppCard(radius: AppRadius.xxxl) {
            HStack(alignment: .center, spacing: AppSpacing.xxl) {
                ZStack {
                    if session.isScanning {
                        Circle()
                            .fill(AppColors.accentMuted.opacity(0.55))
                            .frame(width: 118, height: 118)
                            .scaleEffect(session.isScanning ? 1.06 : 1)
                            .animation(
                                .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                                value: session.isScanning
                            )
                    }

                    AppProgressRing(
                        progress: session.isScanning ? session.progress : (session.hasResults ? 1 : 0),
                        lineWidth: session.isScanning ? 8 : 6,
                        size: session.isScanning ? 104 : 88,
                        showsPercent: true
                    )
                }
                .frame(width: 118, height: 118)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    StatusBadge(
                        title: session.isScanning
                            ? "Scanning \(session.progressPercent)%"
                            : (session.hasResults ? "Scan complete" : "Ready"),
                        style: session.isScanning ? .info : (session.hasResults ? .success : .neutral),
                        icon: session.isScanning ? "circle.dotted" : (session.hasResults ? "checkmark.circle.fill" : "sparkles")
                    )

                    Text(heroTitle)
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(session.isScanning ? session.progressLabel : heroSubtitle)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)

                    Text("\(appState.diskFreeLabel) free")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)

                    if let date = session.lastScanDate, !session.isScanning {
                        Text("Last scan · \(date.formatted(date: .omitted, time: .shortened))")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    HStack(spacing: AppSpacing.sm) {
                        PrimaryButton(
                            title: session.isScanning ? "Scanning…" : "Scan Now",
                            icon: "magnifyingglass",
                            isLoading: session.isScanning
                        ) {
                            Task { await appState.runSmartScan() }
                        }
                        SecondaryButton(title: "Manage Folders", icon: "folder.badge.plus") {
                            appState.showPermissionSetup = true
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var heroTitle: String {
        if session.isScanning {
            return "Scanning your Mac…"
        }
        if session.hasResults {
            return "\(ByteFormat.string(from: session.totalFoundBytes)) found in authorized folders"
        }
        return "Review storage you choose to manage"
    }

    private var heroSubtitle: String {
        if session.hasResults {
            return "Review a category to select items and move them to Trash."
        }
        return "Scan only looks inside folders you authorize."
    }

    private var junkCard: some View {
        AppCard(radius: AppRadius.xxl) {
            HStack(spacing: AppSpacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(AppColors.accentMuted)
                        .frame(width: 44, height: 44)
                    Image(systemName: "trash")
                        .foregroundStyle(AppColors.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Junk space")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(session.junkItemCount) selected cache/log/AI items ready to clean")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                SizeBadge(value: ByteFormat.string(from: session.junkBytes), emphasis: .accent)

                PrimaryButton(
                    title: "Clean Junk",
                    icon: "trash",
                    isLoading: isCleaningJunk,
                    isDisabled: session.junkItemCount == 0 || session.isScanning,
                    size: .compact
                ) {
                    if appState.requireProForCleanJunk() {
                        confirmCleanJunk = true
                    }
                }

                SecondaryButton(title: "Review", size: .compact) {
                    appState.navigate(to: .spaceCleaner)
                }
            }
        }
    }

    private var categoriesGrid: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(
                title: "Categories",
                subtitle: session.hasResults
                    ? "Open a category to review — results are kept from Smart Scan"
                    : "Run Smart Scan to fill categories"
            )

            if session.categorySummaries.isEmpty && !session.isScanning {
                EmptyState(
                    title: "No scan results yet",
                    message: "Tap Scan Now to analyze authorized folders. Results stay available when you navigate away.",
                    systemImage: "sparkles",
                    primaryActionTitle: "Scan Now",
                    primaryAction: {
                        Task { await appState.runSmartScan() }
                    }
                )
                .frame(height: 220)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: AppSpacing.md), GridItem(.flexible(), spacing: AppSpacing.md)],
                    spacing: AppSpacing.md
                ) {
                    ForEach(session.categorySummaries.filter {
                        searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText)
                    }) { category in
                        Button {
                            if let destination = category.destination {
                                appState.navigate(to: destination)
                            }
                        } label: {
                            AppCard(padding: AppSpacing.lg, radius: AppRadius.xxl) {
                                VStack(alignment: .leading, spacing: AppSpacing.md) {
                                    HStack {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                                .fill(AppColors.accentMuted)
                                                .frame(width: 36, height: 36)
                                            Image(systemName: category.systemImage)
                                                .foregroundStyle(AppColors.accent)
                                        }
                                        Spacer()
                                        SizeBadge(value: category.sizeLabel, emphasis: .prominent)
                                    }
                                    Text(category.title)
                                        .font(AppTypography.headline)
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text("\(category.itemCount) items")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textTertiary)
                                    AppProgressBar(progress: category.progress, height: 4)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(session.isScanning)
                    }
                }
            }
        }
    }

    private var tipsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Helpful tips")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Use System Settings → General → Storage for Apple’s built-in storage recommendations. Empty Trash from Finder when you are ready to permanently free space.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                SecondaryButton(title: "Open Storage Settings", size: .compact) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.settings.Storage") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    private func cleanJunk() async {
        isCleaningJunk = true
        let urls = session.junkURLs
        let result = await appState.cleaning.trash(urls: urls)
        let removed = Set(urls.filter { !FileManager.default.fileExists(atPath: $0.path) })
        session.clearAfterClean(removedURLs: removed)
        statusMessage = "Moved \(result.trashedCount) junk items (\(ByteFormat.string(from: result.freedBytes)))."
        appState.refreshDiskStats()
        isCleaningJunk = false
    }
}
