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
                    let root = try await self.buildTree(url: url, parent: nil, continuation: continuation)
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

    private func buildTree(url: URL, parent: FSNode?, continuation: AsyncStream<ScanProgress>.Continuation) throws -> FSNode {
        guard !isCancelled else { throw CancellationError() }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey, .nameKey]
        let res = try url.resourceValues(forKeys: keys)
        guard !(res.isSymbolicLink ?? false) else { throw SkipError() }

        let isDir = res.isDirectory ?? false
        let name = res.name ?? url.lastPathComponent
        let ext = isDir ? "" : url.pathExtension.lowercased()
        let node = FSNode(url: url, name: name, isDirectory: isDir, size: 0, fileExtension: ext, parent: parent)

        if isDir {
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsPackageDescendants]
            )) ?? []

            for childURL in contents {
                guard !isCancelled else { break }
                if let child = try? buildTree(url: childURL, parent: node, continuation: continuation) {
                    node.children.append(child)
                    node.size += child.size
                }
            }
        } else {
            node.size = Int64(res.fileSize ?? 0)
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
