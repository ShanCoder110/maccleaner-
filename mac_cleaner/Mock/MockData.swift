//
//  MockData.swift
//  mac_cleaner
//
//  Preview-only fixtures. Live views use real services.
//

import Foundation

enum MockData {
    static let sampleLog: [ActivityLogEntry] = [
        ActivityLogEntry(kind: .scan, message: "Smart Scan finished"),
        ActivityLogEntry(kind: .clean, message: "Moved 3 items to Trash", path: "/tmp/example")
    ]
}
