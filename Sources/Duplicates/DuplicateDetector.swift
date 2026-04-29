import Foundation
import CryptoKit

public actor DuplicateDetector {
    private let minSize: Int64 = 4 * 1024       // skip files < 4 KB
    private let maxSize: Int64 = 4 * 1024 * 1024 * 1024 // skip files > 4 GB

    public init() {}

    public func detect(in root: FSNode) async {
        var candidates: [FSNode] = []
        collect(node: root, into: &candidates)

        // Group by size first (cheap filter)
        let bySizeRaw = Dictionary(grouping: candidates) { $0.size }
        let bySize = bySizeRaw.filter { $0.value.count > 1 }

        // Hash each group
        var hashGroups: [String: [FSNode]] = [:]
        for (_, nodes) in bySize {
            for node in nodes {
                if let hash = sha256(url: node.url) {
                    let key = "\(node.size)-\(hash)"
                    hashGroups[key, default: []].append(node)
                }
            }
        }

        // Assign group IDs to genuine duplicates (2+ files with same hash+size)
        for (_, nodes) in hashGroups where nodes.count > 1 {
            let groupID = UUID()
            for node in nodes { node.duplicateGroupID = groupID }
        }
    }

    private func collect(node: FSNode, into list: inout [FSNode]) {
        if !node.isDirectory && node.size >= minSize && node.size <= maxSize {
            list.append(node)
        }
        for child in node.children { collect(node: child, into: &list) }
    }

    private func sha256(url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        let chunkSize = 1024 * 1024 // 1MB chunks
        while let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
