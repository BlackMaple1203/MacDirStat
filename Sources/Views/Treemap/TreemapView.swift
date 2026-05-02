import SwiftUI

struct TreemapView: View {
    @EnvironmentObject private var vm: ScanViewModel
    @State private var hoveredCell: TreemapCell?
    @State private var cursorPos: CGPoint = .zero
    @State private var viewSize: CGSize = .zero

    // Recomputed every access so it's never stale
    private var chartCenter: CGPoint {
        CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(nsColor: .windowBackgroundColor)

                // ── Sunburst canvas ──────────────────────────────────────────
                Canvas { context, size in
                    TreemapRenderer.draw(
                        cells: vm.cells,
                        hoveredNode: hoveredCell?.node,
                        selectedNode: vm.selectedNode,
                        highlightedExtension: vm.highlightedExtension,
                        duplicatesReady: vm.duplicatesReady,
                        context: &context,
                        size: size
                    )
                }
                // Track cursor position precisely
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc):
                        cursorPos = loc
                        hoveredCell = TreemapRenderer.cell(
                            at: loc, center: chartCenter, in: vm.cells)
                    case .ended:
                        hoveredCell = nil
                        // keep cursorPos for context-menu hit-test
                    }
                }
                // DragGesture(minimumDistance:0) gives the EXACT click location —
                // TapGesture does not provide location on macOS.
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onEnded { value in
                            // Ignore if the user actually dragged (> 4pt)
                            let dx = value.location.x - value.startLocation.x
                            let dy = value.location.y - value.startLocation.y
                            guard dx*dx + dy*dy < 16 else { return }
                            handleClick(at: value.location)
                        }
                )

                // ── Center overlay ───────────────────────────────────────────
                if vm.isScanning || vm.isComputingLayout {
                    VStack(spacing: 8) {
                        ProgressView().controlSize(.regular)
                        Text(vm.isScanning ? "Scanning…" : "Building…")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(width: TreemapLayout.centerRadius * 2 - 16)
                    .allowsHitTesting(false)
                } else if let root = vm.treemapRoot, !vm.cells.isEmpty {
                    centerLabel(for: root)
                        .allowsHitTesting(false)
                }

                // ── Empty state ──────────────────────────────────────────────
                if vm.cells.isEmpty && !vm.isScanning && !vm.isComputingLayout && vm.root != nil {
                    ContentUnavailableView("Empty Folder", systemImage: "folder",
                        description: Text("This folder contains no files"))
                }

                // ── Hover tooltip (bottom-left) ──────────────────────────────
                if let cell = hoveredCell {
                    HoverTooltip(node: cell.node)
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .bottomLeading)
                        .allowsHitTesting(false)
                }
            }
            // Context menu on the entire ZStack so it fires reliably
            .contextMenu {
                contextMenuContent()
            }
            .onChange(of: geo.size) { _, s in viewSize = s; vm.updateLayoutSize(s) }
            .onAppear        { viewSize = geo.size; vm.updateLayoutSize(geo.size) }
        }
        .animation(.easeInOut(duration: 0.15), value: vm.isScanning)
    }

    // MARK: - Click handler

    private func handleClick(at loc: CGPoint) {
        let c = chartCenter
        guard c.x > 0 else { return }

        if TreemapRenderer.isInCenter(point: loc, center: c) {
            if !vm.drillStack.isEmpty { vm.drillUp() }
            return
        }
        guard let cell = TreemapRenderer.cell(at: loc, center: c, in: vm.cells) else { return }
        if cell.node.isDirectory {
            vm.drillDown(into: cell.node)
        } else {
            vm.select(cell.node)
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenuContent() -> some View {
        // Fresh hit-test so the menu is always accurate even if hover state is stale
        let c = chartCenter
        let node: FSNode? = hoveredCell?.node
            ?? (c.x > 0 ? TreemapRenderer.cell(at: cursorPos, center: c, in: vm.cells)?.node : nil)
            ?? vm.selectedNode

        if let node {
            // Info header (non-interactive)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name).fontWeight(.semibold)
                Text(ByteFormatter.string(from: node.size))
                    .foregroundStyle(.secondary).font(.caption)
            }

            Divider()

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([node.url])
            } label: {
                Label("Reveal in Finder", systemImage: "folder.badge.magnifyingglass")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(node.url.path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.clipboard")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(node.name, forType: .string)
            } label: {
                Label("Copy Name", systemImage: "textformat")
            }

            if node.isDirectory {
                Divider()
                Button {
                    vm.drillDown(into: node)
                } label: {
                    Label("Open in Treemap", systemImage: "arrow.down.right.circle")
                }
            }

            Divider()

            Button(role: .destructive) {
                moveToTrash(node: node)
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }

    // MARK: - Center label

    private func centerLabel(for root: FSNode) -> some View {
        VStack(spacing: 5) {
            if !vm.drillStack.isEmpty {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text("Back")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: FileTypeIcon.systemName(for: root))
                    .font(.system(size: 22))
                    .foregroundStyle(FileTypeIcon.color(for: root))
            }
            Text(root.name)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(ByteFormatter.string(from: root.size))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(width: TreemapLayout.centerRadius * 2 - 20)
    }

    // MARK: - Helpers

    private func moveToTrash(node: FSNode) {
        do {
            try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
            if let root = vm.root { vm.scan(url: root.url) }
        } catch { }
    }
}

// MARK: - Hover tooltip

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

                HStack(spacing: 12) {
                    Label(ByteFormatter.string(from: node.size), systemImage: "internaldrive")
                        .monospacedDigit()
                    if node.isDirectory {
                        Label("\(node.children.count) items", systemImage: "folder")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                Text(node.url.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 4)
    }
}
