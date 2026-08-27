//
//  DuplicateFinder.swift
//  mac_cleaner
//

import Foundation
import CryptoKit

struct DuplicateFinder {
    func findDuplicates(roots: [URL], minimumBytes: Int64 = 100_000, limitGroups: Int = 100) -> [DuplicateGroup] {
        var sizeMap: [Int64: [URL]] = [:]
        let fm = FileManager.default

        for root in roots {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            var seen = 0
            for case let fileURL as URL in enumerator {
                seen += 1
                if seen > 40_000 { break }
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
                if values?.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    continue
                }
                guard values?.isRegularFile == true else { continue }
                let size = Int64(values?.fileSize ?? 0)
                guard size >= minimumBytes else { continue }
                sizeMap[size, default: []].append(fileURL)
            }
        }

        var groups: [DuplicateGroup] = []

        for (size, urls) in sizeMap where urls.count > 1 {
            var partialMap: [String: [URL]] = [:]
            for url in urls {
                let key = partialHash(url) ?? "missing-\(url.path)"
                partialMap[key, default: []].append(url)
            }

            for (_, candidates) in partialMap where candidates.count > 1 {
                var fullMap: [String: [URL]] = [:]
                for url in candidates {
                    let key = fullHash(url) ?? UUID().uuidString
                    fullMap[key, default: []].append(url)
                }

                for (_, dupes) in fullMap where dupes.count > 1 {
                    let files = dupes.map {
                        StorageItem(
                            url: $0,
                            category: "Duplicate",
                            byteSize: size,
                            isSelected: false,
                            modified: FileSizeCalculator.modificationDate(of: $0)
                        )
                    }
                    // Select all but the first by default for reclaim
                    var mutable = files
                    for i in mutable.indices where i > 0 {
                        mutable[i].isSelected = true
                    }
                    groups.append(DuplicateGroup(byteSize: size, files: mutable))
                    if groups.count >= limitGroups { return groups.sorted { $0.byteSize > $1.byteSize } }
                }
            }
        }

        return groups.sorted { $0.reclaimableLabel > $1.reclaimableLabel || $0.byteSize > $1.byteSize }
    }

    private func partialHash(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: 4096)
        guard !data.isEmpty else { return nil }
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    private func fullHash(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }
        // Cap extremely large files to mapped read; if huge, hash in chunks
        if data.count > 200_000_000 {
            return partialHash(url)
        }
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}
