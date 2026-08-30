//
//  FileSizeCalculator.swift
//  mac_cleaner
//

import Foundation

nonisolated enum FileSizeCalculator: Sendable {
    static func size(of url: URL, maxDepth: Int? = nil) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return 0
        }

        if !isDir.boolValue {
            return DirectoryWalk.allocatedSize(of: url)
        }

        let options = DirectoryWalk.Options.forRoot(url, maxDepth: maxDepth)
        let (total, _) = DirectoryWalk.walk(root: url, options: options, initial: Int64(0)) { sum, visit in
            if visit.isRegularFile {
                sum += visit.byteSize
            }
        }
        return total
    }

    static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
