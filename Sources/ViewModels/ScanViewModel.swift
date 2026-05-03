import AppKit
import SwiftUI

@MainActor
public final class ScanViewModel: ObservableObject {
    @Published public var root: FSNode?
    @Published public var cells: [TreemapCell] = []
    @Published public var colorMap: ExtensionColorMap?
    @Published public var selectedNode: FSNode?
    @Published public var isScanning: Bool = false
    @Published public var itemsScanned: Int = 0
    @Published public var bytesFound: Int64 = 0
    @Published public var errorMessage: String?
    @Published public var duplicatesReady: Bool = false
    @Published public var drillStack: [FSNode] = []
    @Published public var highlightedExtension: String?
    @Published public var isComputingLayout: Bool = false
    @Published public var scanURL: URL?
    @Published public var extensionSummaries: [ExtensionSummary] = []
    @Published public var duplicateGroups: [[FSNode]] = []

    public var treemapRoot: FSNode? { drillStack.last ?? root }

    private let scanner = FileScanner()
    private var scanTask: Task<Void, Never>?
    private var layoutSize: CGSize = .zero
    private var layoutGeneration: Int = 0
    private var securityScopedURL: URL?

    public init() {}

    public func scan(url: URL) {
        // Release any previous security scope before acquiring a new one
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil

        // App Sandbox: request access to the user-picked directory
        if url.startAccessingSecurityScopedResource() {
            securityScopedURL = url
        }

        scanTask?.cancel()
        layoutGeneration += 1       // invalidate any in-progress layout
        scanURL = url
        root = nil
        cells = []
        colorMap = nil
        selectedNode = nil
        duplicatesReady = false
        highlightedExtension = nil
        drillStack = []
        extensionSummaries = []
        duplicateGroups = []
        isScanning = true
        itemsScanned = 0
        bytesFound = 0
        isComputingLayout = false
        errorMessage = nil

        scanTask = Task {
            for await progress in await scanner.scan(url: url) {
                switch progress {
                case .update(let items, let bytes):
                    self.itemsScanned = items
                    self.bytesFound = bytes
                case .completed(let node):
                    self.root = node
                    self.isScanning = false
                    self.isComputingLayout = true   // keep spinner until treemap is ready
                    let map = ExtensionColorMap(root: node)
                    self.colorMap = map
                    await self.recomputeLayout()
                    // isComputingLayout set to false inside recomputeLayout

                    // Extension summaries: potentially millions of nodes — run off main actor
                    Task.detached(priority: .userInitiated) { [node, map] in
                        let summaries = Self.buildExtensionSummaries(root: node, map: map)
                        await MainActor.run { self.extensionSummaries = summaries }
                    }
                    // Duplicate detection: lower priority, also off main actor
                    Task.detached(priority: .utility) { [node] in
                        let detector = DuplicateDetector()
                        await detector.detect(in: node)
                        let groups = Self.buildDuplicateGroups(root: node)
                        await MainActor.run {
                            self.duplicatesReady = true
                            self.duplicateGroups = groups
                        }
                    }
                case .failed(let msg):
                    self.errorMessage = msg
                    self.isScanning = false
                    self.isComputingLayout = false
                }
            }
        }
    }

    public func cancelScan() {
        Task { await scanner.cancel() }
        scanTask?.cancel()
        layoutGeneration += 1
        isScanning = false
        isComputingLayout = false
        scanURL = nil
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }

    public func updateLayoutSize(_ size: CGSize) {
        guard size != layoutSize, size.width > 1, size.height > 1 else { return }
        layoutSize = size
        Task { await recomputeLayout() }
    }

    public func drillDown(into node: FSNode) {
        guard node.isDirectory else { return }
        drillStack.append(node)
        Task { await recomputeLayout() }
    }

    public func drillUp() {
        guard !drillStack.isEmpty else { return }
        drillStack.removeLast()
        Task { await recomputeLayout() }
    }

    public func select(_ node: FSNode?) {
        selectedNode = node
    }

    public func highlight(extension ext: String?) {
        highlightedExtension = ext
    }

    private nonisolated static func buildDuplicateGroups(root: FSNode) -> [[FSNode]] {
        var all: [FSNode] = []
        collectAll(node: root, into: &all)
        let grouped = Dictionary(grouping: all.filter { $0.duplicateGroupID != nil }) { $0.duplicateGroupID! }
        return grouped.values
            .filter { $0.count > 1 }
            .sorted { lhs, rhs in
                let wastedLHS = lhs[0].size * Int64(lhs.count - 1)
                let wastedRHS = rhs[0].size * Int64(rhs.count - 1)
                return wastedLHS > wastedRHS
            }
    }

    public struct ExtensionSummary: Identifiable {
        public let id: String
        public let ext: String
        public let color: Color
        public let fileCount: Int
        public let totalSize: Int64
        public let percentage: Double
    }

    private nonisolated static func buildExtensionSummaries(root: FSNode, map: ExtensionColorMap) -> [ExtensionSummary] {
        var groups: [String: (count: Int, size: Int64)] = [:]
        collectExtensions(node: root, into: &groups)
        let total = Double(root.size)
        return groups.map { ext, stats in
            ExtensionSummary(
                id: ext,
                ext: ext.isEmpty ? "(directory)" : ".\(ext)",
                color: map.color(for: ext),
                fileCount: stats.count,
                totalSize: stats.size,
                percentage: total > 0 ? Double(stats.size) / total * 100 : 0
            )
        }
        .sorted { $0.totalSize > $1.totalSize }
    }

    private func recomputeLayout() async {
        guard let displayRoot = treemapRoot, let map = colorMap,
              layoutSize.width > 1, layoutSize.height > 1 else { return }
        layoutGeneration += 1
        let myGen = layoutGeneration
        isComputingLayout = true
        let rect = CGRect(origin: .zero, size: layoutSize)
        let computed = await Task.detached(priority: .userInitiated) {
            TreemapLayout.compute(root: displayRoot, in: rect, colorMap: map)
        }.value
        // Discard result if a newer layout was requested while we were computing
        guard myGen == layoutGeneration else { return }
        self.cells = computed
        self.isComputingLayout = false
    }

    private nonisolated static func collectAll(node: FSNode, into list: inout [FSNode]) {
        var stack = [node]
        while !stack.isEmpty {
            let n = stack.removeLast()
            list.append(n)
            stack.append(contentsOf: n.children)
        }
    }

    private nonisolated static func collectExtensions(node: FSNode, into groups: inout [String: (count: Int, size: Int64)]) {
        var stack = [node]
        while !stack.isEmpty {
            let n = stack.removeLast()
            if !n.isDirectory {
                groups[n.fileExtension, default: (0, 0)].count += 1
                groups[n.fileExtension, default: (0, 0)].size  += n.size
            }
            stack.append(contentsOf: n.children)
        }
    }

    public func exportCSV() {
        guard let root else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(root.name)-disk-usage.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task.detached(priority: .utility) { [root] in
            var lines = ["Path,Size (bytes),Human Size,Type,Duplicate Group"]
            Self.appendCSV(node: root, to: &lines)
            let csv = lines.joined(separator: "\n") + "\n"
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    private nonisolated static func csvEscape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private nonisolated static func appendCSV(node: FSNode, to lines: inout [String]) {
        let type = node.isDirectory ? "directory" : node.fileExtension
        let group = node.duplicateGroupID?.uuidString ?? ""
        lines.append([
            csvEscape(node.url.path),
            "\(node.size)",
            csvEscape(ByteFormatter.string(from: node.size)),
            csvEscape(type),
            csvEscape(group)
        ].joined(separator: ","))
        for child in node.children { appendCSV(node: child, to: &lines) }
    }
}
