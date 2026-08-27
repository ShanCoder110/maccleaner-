//
//  TreemapBuilder.swift
//  mac_cleaner
//

import Foundation

struct TreemapBuilder {
    func build(root: URL, maxChildren: Int = 40, depth: Int = 0, maxDepth: Int = 2) -> TreemapNode {
        let size = FileSizeCalculator.size(of: root, maxDepth: 6)
        guard depth < maxDepth else {
            return TreemapNode(name: root.lastPathComponent, url: root, byteSize: size)
        }

        let childrenURLs = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var childNodes: [TreemapNode] = []
        for url in childrenURLs {
            let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
            if values?.isSymbolicLink == true { continue }
            let node = build(root: url, maxChildren: maxChildren, depth: depth + 1, maxDepth: maxDepth)
            if node.byteSize > 0 {
                childNodes.append(node)
            }
        }

        childNodes.sort { $0.byteSize > $1.byteSize }
        if childNodes.count > maxChildren {
            childNodes = Array(childNodes.prefix(maxChildren))
        }

        return TreemapNode(
            name: root.lastPathComponent.isEmpty ? root.path : root.lastPathComponent,
            url: root,
            byteSize: size,
            children: childNodes
        )
    }
}

/// Simple squarified-style layout rectangles for SwiftUI.
struct TreemapLayout {
    struct Rect: Identifiable, Hashable {
        let id: UUID
        let node: TreemapNode
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    static func layout(nodes: [TreemapNode], in size: CGSize) -> [Rect] {
        guard size.width > 1, size.height > 1 else { return [] }
        let total = nodes.reduce(Int64(0)) { $0 + max($1.byteSize, 1) }
        guard total > 0 else { return [] }

        var remaining = nodes.sorted { $0.byteSize > $1.byteSize }
        var rects: [Rect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var w = size.width
        var h = size.height

        while !remaining.isEmpty {
            let vertical = w >= h
            var row: [TreemapNode] = []
            var rowBytes: Int64 = 0
            let side = vertical ? h : w

            while !remaining.isEmpty {
                let candidate = remaining[0]
                let newRowBytes = rowBytes + max(candidate.byteSize, 1)
                let rowLength = CGFloat(newRowBytes) / CGFloat(total) * (vertical ? w : h)
                // Accept first item always
                if row.isEmpty || worstAspect(row: row + [candidate], side: side, length: rowLength, total: total) <= worstAspect(row: row, side: side, length: CGFloat(rowBytes) / CGFloat(total) * (vertical ? w : h), total: total) + 0.01 {
                    row.append(remaining.removeFirst())
                    rowBytes = newRowBytes
                } else {
                    break
                }
            }

            let rowLength = CGFloat(rowBytes) / CGFloat(total) * (vertical ? w : h)
            var offset: CGFloat = 0
            for node in row {
                let fraction = CGFloat(max(node.byteSize, 1)) / CGFloat(rowBytes)
                let slice = fraction * side
                if vertical {
                    rects.append(Rect(id: node.id, node: node, x: x, y: y + offset, width: max(rowLength, 1), height: max(slice, 1)))
                } else {
                    rects.append(Rect(id: node.id, node: node, x: x + offset, y: y, width: max(slice, 1), height: max(rowLength, 1)))
                }
                offset += slice
            }

            if vertical {
                x += rowLength
                w -= rowLength
            } else {
                y += rowLength
                h -= rowLength
            }
            if w < 1 || h < 1 { break }
        }

        return rects
    }

    private static func worstAspect(row: [TreemapNode], side: CGFloat, length: CGFloat, total: Int64) -> CGFloat {
        guard !row.isEmpty, length > 0, side > 0 else { return .greatestFiniteMagnitude }
        let rowBytes = row.reduce(Int64(0)) { $0 + max($1.byteSize, 1) }
        var worst: CGFloat = 0
        for node in row {
            let area = CGFloat(max(node.byteSize, 1)) / CGFloat(total) * (side * length) // approximate
            let h = area / max(length, 1)
            let aspect = max(length / max(h, 1), max(h, 1) / length)
            worst = max(worst, aspect)
        }
        _ = rowBytes
        return worst
    }
}
