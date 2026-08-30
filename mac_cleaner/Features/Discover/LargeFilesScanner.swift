//
//  LargeFilesScanner.swift
//  mac_cleaner
//

import Foundation

struct LargeFilesScanResult: Sendable {
    var items: [StorageItem]
    var incomplete: Bool
    var itemLimit: Int
    var fileCap: Int

    var warning: String? {
        guard incomplete else { return nil }
        return "Scan incomplete — showing the \(itemLimit.formatted()) largest files. Authorize a smaller folder or raise the size threshold."
    }
}

struct LargeFilesScanner: Sendable {
    var minimumBytes: Int64 = 50 * 1024 * 1024
    var itemLimit: Int = 300
    var fileCap: Int = DirectoryWalk.defaultFileCap

    func scan(roots: [URL], limit: Int? = nil) -> LargeFilesScanResult {
        let itemLimit = limit ?? self.itemLimit
        var items: [StorageItem] = []
        var incomplete = false

        for root in roots {
            if Task.isCancelled { break }
            let options = DirectoryWalk.Options.forRoot(root, maxFiles: fileCap)
            let outcome = DirectoryWalk.walk(root: root, options: options, initial: [StorageItem]()) { acc, visit in
                guard visit.isRegularFile, visit.byteSize >= minimumBytes else { return }
                acc.append(
                    StorageItem(
                        url: visit.url,
                        category: "Large Files",
                        byteSize: visit.byteSize,
                        isSelected: false,
                        isRootOwned: FileOwnership.isOwnedByRoot(visit.url),
                        modified: visit.modified
                    )
                )
            }
            if outcome.incomplete { incomplete = true }
            items.append(contentsOf: outcome.value)
        }

        items.sort { $0.byteSize > $1.byteSize }
        if items.count > itemLimit {
            incomplete = true
            items = Array(items.prefix(itemLimit))
        }

        return LargeFilesScanResult(
            items: items,
            incomplete: incomplete,
            itemLimit: itemLimit,
            fileCap: fileCap
        )
    }
}
