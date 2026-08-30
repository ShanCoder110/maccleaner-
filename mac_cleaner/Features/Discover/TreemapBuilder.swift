//
//  TreemapBuilder.swift
//  mac_cleaner
//
//  Builds a sized folder tree for Space Lens. Depth-2 children for speed;
//  each node is sized with a full allocated-size walk.
//

import Foundation

struct TreemapBuilder: Sendable {
    func build(root: URL, maxChildren: Int = 40, depth: Int = 0, maxDepth: Int = 2) -> TreemapNode {
        let size = FileSizeCalculator.size(of: root)
        guard depth < maxDepth else {
            return TreemapNode(name: root.lastPathComponent, url: root, byteSize: size)
        }

        let hidden = HiddenFilePolicy.forGrantedRoot(root)
        let childrenURLs = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: hidden.enumeratorOptions
        )) ?? []

        var childNodes: [TreemapNode] = []
        for url in childrenURLs {
            if Task.isCancelled { break }
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
