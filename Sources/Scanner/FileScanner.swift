import Foundation

// Thread-safe progress counter using os_unfair_lock
private final class ProgressCounter: @unchecked Sendable {
    private var lock = os_unfair_lock()
    private(set) var items: Int = 0
    private(set) var bytes: Int64 = 0

    func add(items: Int, bytes: Int64) {
        os_unfair_lock_lock(&lock)
        self.items += items
        self.bytes += bytes
        os_unfair_lock_unlock(&lock)
    }

    var snapshot: (items: Int, bytes: Int64) {
        os_unfair_lock_lock(&lock)
        let result = (items, bytes)
        os_unfair_lock_unlock(&lock)
        return result
    }
}

public actor FileScanner {
    private var activeTask: Task<Void, Never>?

    public init() {}

    public func cancel() {
        activeTask?.cancel()
    }

    public func scan(url: URL) -> AsyncStream<ScanProgress> {
        activeTask?.cancel()
        let (stream, continuation) = AsyncStream<ScanProgress>.makeStream()

        activeTask = Task {
            let counter = ProgressCounter()
            // Get the root device ID to detect mount points
            var rootStat = stat()
            let rootDev: dev_t? = (stat(url.path, &rootStat) == 0) ? rootStat.st_dev : nil

            // Emit periodic progress updates every 0.2s
            let progressTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    let s = counter.snapshot
                    continuation.yield(.update(itemsScanned: s.items, bytesFound: s.bytes))
                }
            }

            do {
                let root = try await _buildTree(path: url.path, url: url, parent: nil, rootDev: rootDev, counter: counter)
                progressTask.cancel()
                continuation.yield(.completed(root: root))
            } catch is CancellationError {
                progressTask.cancel()
            } catch {
                progressTask.cancel()
                continuation.yield(.failed(error.localizedDescription))
            }
            continuation.finish()
        }

        return stream
    }
}

// MARK: - POSIX-based parallel tree builder (free functions, not actor-isolated)

private func _buildTree(
    path: String,
    url: URL,
    parent: FSNode?,
    rootDev: dev_t?,
    counter: ProgressCounter
) async throws -> FSNode {
    try Task.checkCancellation()

    var st = stat()
    guard lstat(path, &st) == 0 else { return FSNode(url: url, name: url.lastPathComponent, isDirectory: false, size: 0, fileExtension: "", parent: parent) }

    // Skip symlinks
    if st.st_mode & S_IFMT == S_IFLNK { throw SkipError() }

    let isDir = st.st_mode & S_IFMT == S_IFDIR
    let name = url.lastPathComponent
    let ext = isDir ? "" : url.pathExtension.lowercased()

    let node = FSNode(url: url, name: name, isDirectory: isDir, size: 0, fileExtension: ext, parent: parent)

    if isDir {
        let listing = _listDirectory(path: path, url: url, rootDev: rootDev, node: node, counter: counter)

        // Accumulate direct file sizes immediately
        node.size = listing.totalSize
        node.children = listing.children

        // Recurse into subdirectories in parallel
        if !listing.subdirPaths.isEmpty {
            var subdirSize: Int64 = 0
            try await withThrowingTaskGroup(of: FSNode?.self) { group in
                for (subPath, subURL) in listing.subdirPaths {
                    group.addTask {
                        try Task.checkCancellation()
                        return try await _buildTree(path: subPath, url: subURL, parent: node, rootDev: rootDev, counter: counter)
                    }
                }
                for try await child in group {
                    guard let child else { continue }
                    node.children.append(child)
                    subdirSize += child.size
                }
            }
            node.size += subdirSize
        }

        counter.add(items: 1, bytes: 0)
    } else {
        // Allocated size: st_blocks * 512 gives actual disk usage
        let allocatedSize = Int64(st.st_blocks) * 512
        node.size = allocatedSize
        counter.add(items: 1, bytes: allocatedSize)
    }

    return node
}

private struct SubdirEntry {
    let path: String
    let url: URL
}

private struct DirectoryContents {
    var children: [FSNode]       // immediate file children already created
    var subdirPaths: [(String, URL)]  // subdirectory (path, url) pairs for parallel recursion
    var totalSize: Int64         // sum of immediate file sizes
    var itemCount: Int           // count of items processed here
}

private func _listDirectory(path: String, url: URL, rootDev: dev_t?, node: FSNode, counter: ProgressCounter) -> DirectoryContents {
    var result = DirectoryContents(children: [], subdirPaths: [], totalSize: 0, itemCount: 0)

    guard let dir = opendir(path) else { return result }
    defer { closedir(dir) }
    let directoryFD = dirfd(dir)

    while let entry = readdir(dir) {
        let nameBytes = entry.pointee.d_name
        let name: String = withUnsafeBytes(of: nameBytes) { ptr in
            let bytes = ptr.bindMemory(to: CChar.self)
            return String(cString: bytes.baseAddress!)
        }
        guard name != "." && name != ".." else { continue }

        let childURL = url.appendingPathComponent(name, isDirectory: entry.pointee.d_type == DT_DIR)
        let dtype = entry.pointee.d_type

        // Fast type check using d_type from dirent (avoids extra stat call for most entries)
        if dtype == DT_LNK { continue }  // skip symlinks

        if dtype == DT_DIR || dtype == DT_UNKNOWN {
            // For DT_UNKNOWN (e.g. some network filesystems), use lstat
            var st = stat()
            let childPath = path.hasSuffix("/") ? path + name : path + "/" + name
            if dtype == DT_UNKNOWN {
                guard fstatat(directoryFD, name, &st, AT_SYMLINK_NOFOLLOW) == 0 else { continue }
                let mode = st.st_mode & S_IFMT
                if mode == S_IFLNK { continue }
                if mode != S_IFDIR {
                    // It's a regular file with DT_UNKNOWN
                    let allocSize = Int64(st.st_blocks) * 512
                    let ext = childURL.pathExtension.lowercased()
                    let fileNode = FSNode(url: childURL, name: name, isDirectory: false, size: allocSize, fileExtension: ext, parent: node)
                    result.children.append(fileNode)
                    result.totalSize += allocSize
                    result.itemCount += 1
                    counter.add(items: 1, bytes: allocSize)
                    continue
                }
                // Check mount point via st_dev
                if let rootDev, st.st_dev != rootDev { continue }
                result.subdirPaths.append((childPath, childURL))
            } else {
                // DT_DIR — check mount point via a quick stat
                if let rootDev {
                    guard fstatat(directoryFD, name, &st, 0) == 0 else { continue }
                    if st.st_dev != rootDev { continue }
                }
                result.subdirPaths.append((childPath, childURL))
            }
        } else if dtype == DT_REG {
            var st = stat()
            guard fstatat(directoryFD, name, &st, AT_SYMLINK_NOFOLLOW) == 0 else { continue }
            let allocSize = Int64(st.st_blocks) * 512
            let ext = childURL.pathExtension.lowercased()
            let fileNode = FSNode(url: childURL, name: name, isDirectory: false, size: allocSize, fileExtension: ext, parent: node)
            result.children.append(fileNode)
            result.totalSize += allocSize
            result.itemCount += 1
            counter.add(items: 1, bytes: allocSize)
        }
        // DT_FIFO, DT_CHR, DT_BLK, DT_SOCK — skip
    }

    return result
}

private struct SkipError: Error {}
