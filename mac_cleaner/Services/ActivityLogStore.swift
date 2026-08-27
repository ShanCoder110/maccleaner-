//
//  ActivityLogStore.swift
//  mac_cleaner
//

import Foundation
import Combine

final class ActivityLogStore: ObservableObject {
    @Published private(set) var entries: [ActivityLogEntry] = []
    private let storageKey = "mas.activityLog"
    private let maxAgeDays = 30

    init() {
        load()
        prune()
    }

    func log(_ kind: ActivityKind, _ message: String, path: String? = nil) {
        let entry = ActivityLogEntry(kind: kind, message: message, path: path)
        entries.insert(entry, at: 0)
        prune()
        persist()
    }

    func clear() {
        entries.removeAll()
        persist()
    }

    var errorEntries: [ActivityLogEntry] {
        entries.filter { $0.kind == .error }
    }

    private func prune() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxAgeDays, to: Date()) ?? Date.distantPast
        entries.removeAll { $0.date < cutoff }
        if entries.count > 1000 {
            entries = Array(entries.prefix(1000))
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ActivityLogEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
