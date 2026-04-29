import SwiftUI

struct TreemapView: View {
    @EnvironmentObject private var vm: ScanViewModel
    @State private var hoveredCell: TreemapCell?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { context, size in
                    TreemapRenderer.draw(
                        cells: vm.cells,
                        selectedNode: vm.selectedNode,
                        highlightedExtension: vm.highlightedExtension,
                        duplicatesReady: vm.duplicatesReady,
                        context: &context,
                        size: size
                    )
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc):
                        hoveredCell = TreemapRenderer.cell(at: loc, in: vm.cells)
                    case .ended:
                        hoveredCell = nil
                    }
                }
                .gesture(
                    TapGesture(count: 2).onEnded {
                        if let cell = hoveredCell { vm.drillDown(into: cell.node) }
                    }
                )
                .simultaneousGesture(
                    TapGesture(count: 1).onEnded {
                        if let cell = hoveredCell { vm.select(cell.node) }
                    }
                )
                .contextMenu {
                    if let node = hoveredCell?.node ?? vm.selectedNode {
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([node.url])
                        }
                        Button("Copy Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(node.url.path, forType: .string)
                        }
                        Divider()
                        Button("Move to Trash", role: .destructive) {
                            moveToTrash(node: node)
                        }
                    }
                }

                // Hover tooltip
                if let cell = hoveredCell {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cell.node.name).fontWeight(.semibold)
                        Text(ByteFormatter.string(from: cell.node.size)).foregroundStyle(.secondary)
                        Text(cell.node.url.path)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 4)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .allowsHitTesting(false)
                }

                // Empty state
                if vm.cells.isEmpty && !vm.isScanning {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "square.3.layers.3d",
                        description: Text(vm.root == nil ? "Open a folder to begin" : "Nothing to display")
                    )
                }
            }
            .onChange(of: geo.size) { _, size in vm.updateLayoutSize(size) }
            .onAppear { vm.updateLayoutSize(geo.size) }
        }
    }

    private func moveToTrash(node: FSNode) {
        do {
            var resultURL: NSURL?
            try FileManager.default.trashItem(at: node.url, resultingItemURL: &resultURL)
            if let root = vm.root { vm.scan(url: root.url) }
        } catch {
            // silently ignore — file may already be gone
        }
    }
}
