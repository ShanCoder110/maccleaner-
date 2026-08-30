//
//  DirectoryWalk.swift
//  mac_cleaner
//
//  Shared sync walk for Large Files, Space Lens, and size calculation.
//  Uses allocated size so sparse files (Docker.raw) match disk use.
//

import Foundation

enum HiddenFilePolicy: Sendable, Equatable {
    case skipHidden
    case includeHidden

    /// Library grants include hidden files; other granted folders skip them.
    static func forGrantedRoot(_ url: URL) -> HiddenFilePolicy {
        let path = url.standardizedFileURL.path.lowercased()
        if path == "library" || path.hasSuffix("/library") || path.contains("/library/") {
            return .includeHidden
        }
        return .skipHidden
    }

    var enumeratorOptions: FileManager.DirectoryEnumerationOptions {
        switch self {
        case .skipHidden: return [.skipsHiddenFiles]
        case .includeHidden: return []
        }
    }
}

enum DirectoryWalk: Sendable {
    static let defaultFileCap = 80_000

    struct Options: Sendable {
        var hidden: HiddenFilePolicy
        var skipPackageDescendants: Bool
        var maxFiles: Int
        var maxDepth: Int?

        static func forRoot(
            _ url: URL,
            maxFiles: Int = DirectoryWalk.defaultFileCap,
            maxDepth: Int? = nil,
            skipPackageDescendants: Bool = false
        ) -> Options {
            Options(
                hidden: .forGrantedRoot(url),
                skipPackageDescendants: skipPackageDescendants,
                maxFiles: maxFiles,
                maxDepth: maxDepth
            )
        }

        var enumeratorOptions: FileManager.DirectoryEnumerationOptions {
            var options = hidden.enumeratorOptions
            if skipPackageDescendants {
                options.insert(.skipsPackageDescendants)
            }
            return options
        }
    }

    struct Visit: Sendable {
        let url: URL
        let byteSize: Int64
        let modified: Date?
        let isRegularFile: Bool
        let isSymbolicLink: Bool
    }

    static func walk<T>(
        root: URL,
        options: Options,
        initial: T,
        visit: (inout T, Visit) -> Void
    ) -> (value: T, incomplete: Bool) {
        var value = initial
        var incomplete = false
        var seen = 0

        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .contentModificationDateKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: options.enumeratorOptions
        ) else {
            return (value, false)
        }

        for case let fileURL as URL in enumerator {
            if Task.isCancelled {
                incomplete = true
                break
            }
            seen += 1
            if seen > options.maxFiles {
                incomplete = true
                break
            }

            let values = try? fileURL.resourceValues(forKeys: keys)
            if values?.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }

            if let maxDepth = options.maxDepth, enumerator.level > maxDepth {
                enumerator.skipDescendants()
            }

            visit(
                &value,
                Visit(
                    url: fileURL,
                    byteSize: allocatedSize(from: values),
                    modified: values?.contentModificationDate,
                    isRegularFile: values?.isRegularFile == true,
                    isSymbolicLink: values?.isSymbolicLink == true
                )
            )
        }

        return (value, incomplete)
    }

    static func allocatedSize(of url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey
        ])
        return allocatedSize(from: values)
    }

    static func allocatedSize(from values: URLResourceValues?) -> Int64 {
        guard let values else { return 0 }
        if let allocated = values.totalFileAllocatedSize, allocated > 0 {
            return Int64(allocated)
        }
        if let allocated = values.fileAllocatedSize, allocated > 0 {
            return Int64(allocated)
        }
        return Int64(values.fileSize ?? 0)
    }
}
