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

    public var treemapRoot: FSNode? { drillStack.last ?? root }

    private let scanner = FileScanner()
    private var scanTask: Task<Void, Never>?
    private var layoutSize: CGSize = .zero

    public init() {}

    public func scan(url: URL) {
        scanTask?.cancel()
        root = nil
        cells = []
        colorMap = nil
        selectedNode = nil
        duplicatesReady = false
        highlightedExtension = nil
        drillStack = []
        isScanning = true
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
                    let map = ExtensionColorMap(root: node)
                    self.colorMap = map
                    await self.recomputeLayout()
                    Task.detached(priority: .utility) { [node] in
                        let detector = DuplicateDetector()
                        await detector.detect(in: node)
                        await MainActor.run { self.duplicatesReady = true }
                    }
                case .failed(let msg):
                    self.errorMessage = msg
                    self.isScanning = false
                }
            }
        }
    }

    public func cancelScan() {
        Task { await scanner.cancel() }
        scanTask?.cancel()
        isScanning = false
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

    public var duplicateGroups: [[FSNode]] {
        guard let root else { return [] }
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

    public var extensionSummaries: [ExtensionSummary] {
        guard let root, let map = colorMap else { return [] }
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
        let rect = CGRect(origin: .zero, size: layoutSize)
        let computed = await Task.detached(priority: .userInitiated) {
            TreemapLayout.compute(root: displayRoot, in: rect, colorMap: map)
        }.value
        self.cells = computed
    }

    private func collectAll(node: FSNode, into list: inout [FSNode]) {
        list.append(node)
        for child in node.children { collectAll(node: child, into: &list) }
    }

    private func collectExtensions(node: FSNode, into groups: inout [String: (count: Int, size: Int64)]) {
        if !node.isDirectory {
            let key = node.fileExtension
            groups[key, default: (0, 0)].count += 1
            groups[key, default: (0, 0)].size += node.size
        }
        for child in node.children { collectExtensions(node: child, into: &groups) }
    }

    public func exportCSV() {
        guard let root else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(root.name)-disk-usage.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var lines = ["Path,Size (bytes),Size,Type,Duplicate Group"]
        appendCSV(node: root, to: &lines)
        let csv = lines.joined(separator: "\n")

        Task.detached(priority: .utility) {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func appendCSV(node: FSNode, to lines: inout [String]) {
        let path = node.url.path.replacingOccurrences(of: ",", with: ";")
        let type = node.isDirectory ? "directory" : node.fileExtension
        let group = node.duplicateGroupID?.uuidString ?? ""
        lines.append("\"\(path)\",\(node.size),\(ByteFormatter.string(from: node.size)),\(type),\(group)")
        for child in node.children { appendCSV(node: child, to: &lines) }
    }
}
