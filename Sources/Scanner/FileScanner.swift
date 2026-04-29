import Foundation

public actor FileScanner {
    private var itemsScanned = 0
    private var bytesFound: Int64 = 0
    private(set) public var isCancelled = false

    public init() {}

    public func cancel() { isCancelled = true }

    public func scan(url: URL) -> AsyncStream<ScanProgress> {
        itemsScanned = 0
        bytesFound = 0
        isCancelled = false

        return AsyncStream { continuation in
            Task { [weak self] in
                guard let self else { return }
                do {
                    let rootRes = try url.resourceValues(forKeys: [.volumeIdentifierKey])
                    let rootVolumeID = rootRes.volumeIdentifier
                    let root = try await self.buildTree(url: url, parent: nil, rootVolumeID: rootVolumeID, continuation: continuation)
                    continuation.yield(.completed(root: root))
                } catch is CancellationError {
                    // cancelled — emit nothing extra
                } catch {
                    continuation.yield(.failed(error.localizedDescription))
                }
                continuation.finish()
            }
        }
    }

    private static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .nameKey,
        .totalFileAllocatedSizeKey, .volumeIdentifierKey
    ]

    private func buildTree(
        url: URL,
        parent: FSNode?,
        rootVolumeID: (any NSCopying & NSObjectProtocol)?,
        continuation: AsyncStream<ScanProgress>.Continuation
    ) throws -> FSNode {
        guard !isCancelled else { throw CancellationError() }

        let res = try url.resourceValues(forKeys: Self.resourceKeys)
        guard !(res.isSymbolicLink ?? false) else { throw SkipError() }

        let isDir = res.isDirectory ?? false
        let name = res.name ?? url.lastPathComponent
        let ext = isDir ? "" : url.pathExtension.lowercased()
        let node = FSNode(url: url, name: name, isDirectory: isDir, size: 0, fileExtension: ext, parent: parent)

        if isDir {
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(Self.resourceKeys),
                options: [.skipsPackageDescendants]
            )) ?? []

            for childURL in contents {
                guard !isCancelled else { break }
                // Skip mount points — don't follow into other filesystems
                if let rootVolumeID,
                   let childVol = try? childURL.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier,
                   !childVol.isEqual(rootVolumeID) {
                    continue
                }
                if let child = try? buildTree(url: childURL, parent: node, rootVolumeID: rootVolumeID, continuation: continuation) {
                    node.children.append(child)
                    node.size += child.size
                }
            }
        } else {
            // Use allocated size (actual disk blocks), not logical file size.
            // This correctly handles sparse files (e.g. Docker.raw, VM images).
            node.size = Int64(res.totalFileAllocatedSize ?? 0)
            bytesFound += node.size
        }

        itemsScanned += 1
        if itemsScanned % 500 == 0 {
            continuation.yield(.update(itemsScanned: itemsScanned, bytesFound: bytesFound))
        }
        return node
    }
}

private struct SkipError: Error {}
