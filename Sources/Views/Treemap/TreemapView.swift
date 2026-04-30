import SwiftUI

struct TreemapView: View {
    @EnvironmentObject private var vm: ScanViewModel
    @State private var hoveredCell: TreemapCell?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Color(nsColor: .windowBackgroundColor)

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

                // Scanning / layout-computing overlay spinner (top-right corner)
                if vm.isScanning || vm.isComputingLayout {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Scanning…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(12)
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }

                // Hover tooltip
                if let cell = hoveredCell {
                    HoverTooltip(node: cell.node)
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .allowsHitTesting(false)
                        .transition(.opacity.animation(.easeInOut(duration: 0.1)))
                }

                // Empty directory (root exists but no cells)
                if vm.cells.isEmpty && !vm.isScanning && vm.root != nil {
                    ContentUnavailableView(
                        "Empty Folder",
                        systemImage: "folder",
                        description: Text("This folder contains no files")
                    )
                }
            }
            .clipShape(Rectangle())
            .onChange(of: geo.size) { _, size in vm.updateLayoutSize(size) }
            .onAppear { vm.updateLayoutSize(geo.size) }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.isScanning)
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

private struct HoverTooltip: View {
    let node: FSNode

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: FileTypeIcon.systemName(for: node))
                .foregroundStyle(FileTypeIcon.color(for: node))
                .font(.system(size: 22))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.system(.body, weight: .semibold))
                    .lineLimit(1)

                Label(ByteFormatter.string(from: node.size), systemImage: "internaldrive")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Text(node.url.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
    }
}
