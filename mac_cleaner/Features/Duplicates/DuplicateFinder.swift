//
//  DuplicateFinder.swift
//  mac_cleaner
//
//  Exact duplicate detection: size → partial hash → full streaming SHA-256.
//  Do not add perceptual / similar-photo matching.
//

import Foundation
import CryptoKit

struct DuplicateFinder: Sendable {
    static let minimumBytes: Int64 = 100_000
    static let defaultEntryLimitPerRoot = 60_000
    static let defaultGroupLimit = 150
    static let partialHashBytes = 4096
    static let streamChunkBytes = 1024 * 1024

    var entryLimitPerRoot: Int
    var groupLimit: Int

    init(
        entryLimitPerRoot: Int = DuplicateFinder.defaultEntryLimitPerRoot,
        groupLimit: Int = DuplicateFinder.defaultGroupLimit
    ) {
        self.entryLimitPerRoot = entryLimitPerRoot
        self.groupLimit = groupLimit
    }

    func findDuplicates(
        roots: [URL],
        minimumBytes: Int64 = DuplicateFinder.minimumBytes,
        limitGroups: Int? = nil
    ) -> DuplicateScanResult {
        let limitGroups = limitGroups ?? groupLimit
        var sizeMap: [Int64: [URL]] = [:]
        let fm = FileManager.default
        var hitEntryLimit = false

        for root in roots {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            var seen = 0
            for case let fileURL as URL in enumerator {
                if Task.isCancelled {
                    return makeResult(groups: [], hitEntryLimit: hitEntryLimit, hitGroupLimit: false)
                }
                seen += 1
                if seen > entryLimitPerRoot {
                    hitEntryLimit = true
                    break
                }
                let values = try? fileURL.resourceValues(forKeys: [
                    .isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey
                ])
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
        var hitGroupLimit = false

        for (size, urls) in sizeMap where urls.count > 1 {
            if Task.isCancelled {
                return makeResult(groups: sorted(groups), hitEntryLimit: hitEntryLimit, hitGroupLimit: hitGroupLimit)
            }
            var partialMap: [String: [URL]] = [:]
            for url in urls {
                if Task.isCancelled {
                    return makeResult(groups: sorted(groups), hitEntryLimit: hitEntryLimit, hitGroupLimit: hitGroupLimit)
                }
                let key = partialHash(url) ?? "missing-\(url.path)"
                partialMap[key, default: []].append(url)
            }

            for (_, candidates) in partialMap where candidates.count > 1 {
                var fullMap: [String: [URL]] = [:]
                var failedFullHash: [URL] = []

                for url in candidates {
                    if Task.isCancelled {
                        return makeResult(groups: sorted(groups), hitEntryLimit: hitEntryLimit, hitGroupLimit: hitGroupLimit)
                    }
                    if let key = streamHash(url) {
                        fullMap[key, default: []].append(url)
                    } else {
                        failedFullHash.append(url)
                    }
                }

                for (_, dupes) in fullMap where dupes.count > 1 {
                    if let group = makeGroup(
                        urls: dupes,
                        size: size,
                        confidence: .confirmed,
                        hashState: .fullVerified
                    ) {
                        groups.append(group)
                        if groups.count >= limitGroups {
                            return makeResult(groups: sorted(groups), hitEntryLimit: hitEntryLimit, hitGroupLimit: true)
                        }
                    }
                }

                // Partial-hash matches that could not be fully verified → possible only.
                if failedFullHash.count > 1 {
                    if let group = makeGroup(
                        urls: failedFullHash,
                        size: size,
                        confidence: .possible,
                        hashState: .partialOnly
                    ) {
                        groups.append(group)
                        if groups.count >= limitGroups {
                            return makeResult(groups: sorted(groups), hitEntryLimit: hitEntryLimit, hitGroupLimit: true)
                        }
                    }
                }
            }
        }

        return makeResult(groups: sorted(groups), hitEntryLimit: hitEntryLimit, hitGroupLimit: hitGroupLimit)
    }

    private func makeResult(
        groups: [DuplicateGroup],
        hitEntryLimit: Bool,
        hitGroupLimit: Bool
    ) -> DuplicateScanResult {
        DuplicateScanResult(
            groups: groups,
            hitEntryLimit: hitEntryLimit,
            hitGroupLimit: hitGroupLimit,
            entryLimit: entryLimitPerRoot,
            groupLimit: groupLimit
        )
    }

    private func sorted(_ groups: [DuplicateGroup]) -> [DuplicateGroup] {
        DuplicateListHelpers.sorted(groups, by: .recoverableSize)
    }

    private func makeGroup(
        urls: [URL],
        size: Int64,
        confidence: DuplicateConfidence,
        hashState: DuplicateHashState
    ) -> DuplicateGroup? {
        guard urls.count > 1 else { return nil }

        var files = urls.map { url -> DuplicateFile in
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
            return DuplicateFile(
                url: url,
                byteSize: size,
                modified: values?.contentModificationDate ?? FileSizeCalculator.modificationDate(of: url),
                created: values?.creationDate,
                hashState: hashState,
                isSelected: false
            )
        }

        let recommendation: DuplicateKeepRecommendation
        let keepID: UUID?

        if confidence == .confirmed {
            let applied = DuplicateKeepScorer.applyRecommendation(to: files)
            files = applied.files
            keepID = applied.keepID
            recommendation = applied.recommendation
        } else {
            // Possible duplicates: never auto-select for deletion.
            for i in files.indices {
                files[i].isSelected = false
                files[i].isRecommendedKeep = false
                files[i].keepReason = .noClearPreference
            }
            keepID = nil
            recommendation = .noClearRecommendation
        }

        return DuplicateGroup(
            byteSize: size,
            files: files,
            confidence: confidence,
            keepRecommendation: recommendation,
            keepID: keepID
        )
    }

    /// First N bytes — candidate filter only.
    private func partialHash(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: Self.partialHashBytes)
        guard !data.isEmpty else { return nil }
        return hex(SHA256.hash(data: data))
    }

    /// Full-file SHA-256 via chunked streaming (never load whole file into memory).
    private func streamHash(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        var readAny = false
        while true {
            if Task.isCancelled { return nil }
            let chunk = handle.readData(ofLength: Self.streamChunkBytes)
            if chunk.isEmpty { break }
            readAny = true
            hasher.update(data: chunk)
        }
        guard readAny else { return nil }
        return hex(hasher.finalize())
    }

    private func hex(_ digest: SHA256Digest) -> String {
        digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
