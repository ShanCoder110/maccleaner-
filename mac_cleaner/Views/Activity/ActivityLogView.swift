//
//  ActivityLogView.swift
//  mac_cleaner
//

import SwiftUI
import AppKit

struct ActivityLogView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var activityLog: ActivityLogStore

    @State private var searchText = ""
    @State private var filter = "All"

    private var filtered: [ActivityLogEntry] {
        activityLog.entries.filter { entry in
            let matchesFilter: Bool = {
                switch filter {
                case "Errors": return entry.kind == .error
                case "Cleans": return entry.kind == .clean
                case "Scans": return entry.kind == .scan
                default: return true
                }
            }()
            let matchesSearch = searchText.isEmpty
                || entry.message.localizedCaseInsensitiveContains(searchText)
                || (entry.path?.localizedCaseInsensitiveContains(searchText) ?? false)
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbar(
                title: "Activity",
                subtitle: "Local history of scans and Trash actions",
                searchText: $searchText,
                searchPlaceholder: "Search activity"
            )

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack {
                    AppSegmentedControl(
                        options: [("All", "All"), ("Scans", "Scans"), ("Cleans", "Cleans"), ("Errors", "Errors")],
                        selection: $filter
                    )
                    Spacer()
                    SecondaryButton(title: "Copy", icon: "doc.on.doc", size: .compact) {
                        copyLog()
                    }
                    SecondaryButton(title: "Clear", size: .compact) {
                        activityLog.clear()
                    }
                }

                if filtered.isEmpty {
                    EmptyState(
                        title: "No activity yet",
                        message: "Scans and clean actions will appear here. Logs prune automatically after 30 days.",
                        systemImage: "list.bullet.rectangle"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(filtered) { entry in
                                AppCard(padding: AppSpacing.md, radius: AppRadius.xl, showShadow: false) {
                                    HStack(alignment: .top, spacing: AppSpacing.md) {
                                        StatusBadge(
                                            title: label(for: entry.kind),
                                            style: style(for: entry.kind)
                                        )
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(entry.message)
                                                .font(AppTypography.bodyMedium)
                                                .foregroundStyle(AppColors.textPrimary)
                                            if let path = entry.path {
                                                Text(path)
                                                    .font(AppTypography.caption)
                                                    .foregroundStyle(AppColors.textTertiary)
                                                    .lineLimit(2)
                                            }
                                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                                .font(AppTypography.micro)
                                                .foregroundStyle(AppColors.textTertiary)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.contentInset)
        }
        .background(Color.clear)
    }

    private func label(for kind: ActivityKind) -> String {
        switch kind {
        case .scan: return "Scan"
        case .clean: return "Clean"
        case .error: return "Error"
        case .info: return "Info"
        }
    }

    private func style(for kind: ActivityKind) -> StatusBadgeStyle {
        switch kind {
        case .scan: return .info
        case .clean: return .success
        case .error: return .danger
        case .info: return .neutral
        }
    }

    private func copyLog() {
        let text = filtered.map { entry in
            let path = entry.path.map { " | \($0)" } ?? ""
            return "[\(entry.date.ISO8601Format())] \(label(for: entry.kind)): \(entry.message)\(path)"
        }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        activityLog.log(.info, "Copied \(filtered.count) log lines")
    }
}
