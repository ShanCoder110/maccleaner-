//
//  LargeFilesScanner.swift
//  mac_cleaner
//

import Foundation

struct LargeFilesScanner {
    var minimumBytes: Int64 = 50 * 1024 * 1024

    func scan(roots: [URL], limit: Int = 300) -> [StorageItem] {
        var items: [StorageItem] = []
        let fm = FileManager.default

        for root in roots {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                if items.count >= limit { break }
                let values = try? fileURL.resourceValues(forKeys: [
                    .isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .isSymbolicLinkKey
                ])
                if values?.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    continue
                }
                guard values?.isRegularFile == true else { continue }
                let size = Int64(values?.fileSize ?? 0)
                guard size >= minimumBytes else { continue }

                items.append(
                    StorageItem(
                        url: fileURL,
                        category: "Large Files",
                        byteSize: size,
                        isSelected: false,
                        modified: values?.contentModificationDate
                    )
                )
            }
        }

        return items.sorted { $0.byteSize > $1.byteSize }
    }
}
