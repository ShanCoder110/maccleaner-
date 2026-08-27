//
//  FileSizeCalculator.swift
//  mac_cleaner
//

import Foundation

enum FileSizeCalculator {
    static func size(of url: URL, maxDepth: Int = 8) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return 0
        }

        if !isDir.boolValue {
            return (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        }

        return directorySize(url: url, depth: 0, maxDepth: maxDepth)
    }

    private static func directorySize(url: URL, depth: Int, maxDepth: Int) -> Int64 {
        guard depth <= maxDepth else { return 0 }
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return 0
        }

        var total: Int64 = 0
        var count = 0
        for case let fileURL as URL in enumerator {
            count += 1
            if count > 50_000 { break }

            let values = try? fileURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
            if values?.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
            if enumerator.level > maxDepth {
                enumerator.skipDescendants()
            }
        }
        return total
    }

    static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
