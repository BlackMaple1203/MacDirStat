import SwiftUI

struct TreemapView: View {
    @EnvironmentObject private var vm: ScanViewModel
    @State private var hoveredCell: TreemapCell?
    @State private var cursorPos: CGPoint = .zero
    @State private var viewSize: CGSize = .zero
    @State private var drillGeneration: Int = 0   // increments on drill for transition

    private var chartCenter: CGPoint {
        CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
    }

    var body: some View {
        GeometryReader { geo in
            // TimelineView drives the pulsing glow on the selected arc.
            // Paused when nothing is selected so we don't burn CPU.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                    paused: vm.selectedNode == nil)) { timeline in
                let pulse = pulsePhase(from: timeline)
                mainContent(pulse: pulse)
                    .onChange(of: geo.size) { _, s in viewSize = s; vm.updateLayoutSize(s) }
                    .onAppear { viewSize = geo.size; vm.updateLayoutSize(geo.size) }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: vm.isScanning)
    }

    // MARK: - Main canvas

    @ViewBuilder
    private func mainContent(pulse: Double) -> some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            // Canvas tagged with drillGeneration so SwiftUI replaces it (with
            // a cross-fade transition) each time the user drills in or out.
            Canvas { ctx, size in
                TreemapRenderer.draw(
                    cells: vm.cells,
                    hoveredNode: hoveredCell?.node,
                    selectedNode: vm.selectedNode,
                    highlightedExtension: vm.highlightedExtension,
                    duplicatesReady: vm.duplicatesReady,
                    pulsePhase: pulse,
                    context: &ctx,
                    size: size
                )
            }
            .id(drillGeneration)
            .transition(.opacity.animation(.easeInOut(duration: 0.22)))
            .onContinuousHover { phase in
                switch phase {
                case .active(let loc):
                    cursorPos = loc
                    hoveredCell = TreemapRenderer.cell(at: loc, center: chartCenter, in: vm.cells)
                case .ended:
                    hoveredCell = nil
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onEnded { value in
                        let dx = value.location.x - value.startLocation.x
                        let dy = value.location.y - value.startLocation.y
                        guard dx * dx + dy * dy < 16 else { return }
                        handleClick(at: value.location)
                    }
            )

            // ── Scanning / building spinner ──────────────────────────────────
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

            // ── Empty folder ─────────────────────────────────────────────────
            if vm.cells.isEmpty, !vm.isScanning, !vm.isComputingLayout, vm.root != nil {
                ContentUnavailableView("Empty Folder", systemImage: "folder",
                    description: Text("This folder contains no files"))
            }

            // ── Hover tooltip ────────────────────────────────────────────────
            if let cell = hoveredCell {
                HoverTooltip(node: cell.node)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .allowsHitTesting(false)
                    .transition(.opacity.animation(.easeInOut(duration: 0.12)))
            }
        }
        .contextMenu { contextMenuContent() }
    }

    // MARK: - Click

    private func handleClick(at loc: CGPoint) {
        let c = chartCenter
        guard c.x > 0 else { return }

        if TreemapRenderer.isInCenter(point: loc, center: c) {
            guard !vm.drillStack.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.22)) { drillGeneration += 1 }
            vm.drillUp()
            return
        }
        guard let cell = TreemapRenderer.cell(at: loc, center: c, in: vm.cells) else { return }
        if cell.node.isDirectory {
            withAnimation(.easeInOut(duration: 0.22)) { drillGeneration += 1 }
            vm.drillDown(into: cell.node)
        } else {
            vm.select(cell.node)
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenuContent() -> some View {
        let c = chartCenter
        let node: FSNode? = hoveredCell?.node
            ?? (c.x > 0 ? TreemapRenderer.cell(at: cursorPos, center: c, in: vm.cells)?.node : nil)
            ?? vm.selectedNode

        if let node {
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
                    withAnimation(.easeInOut(duration: 0.22)) { drillGeneration += 1 }
                    vm.drillDown(into: node)
                } label: {
                    Label("Open in Chart", systemImage: "arrow.down.right.circle")
                }
            }

            Divider()

            Button(role: .destructive) {
                do {
                    try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
                    if let root = vm.root { vm.scan(url: root.url) }
                } catch {}
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }

    // MARK: - Center label

    private func centerLabel(for root: FSNode) -> some View {
        VStack(spacing: 4) {
            if !vm.drillStack.isEmpty {
                Image(systemName: "chevron.backward.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text("Back")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.quaternary)
            } else {
                Image(systemName: FileTypeIcon.systemName(for: root))
                    .font(.system(size: 20))
                    .foregroundStyle(FileTypeIcon.color(for: root))
            }
            Text(root.name)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
            Text(ByteFormatter.string(from: root.size))
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(width: TreemapLayout.centerRadius * 2 - 20)
        .contentTransition(.numericText())
        .animation(.easeInOut(duration: 0.3), value: root.id)
    }

    // MARK: - Helpers

    private func pulsePhase(from timeline: TimelineViewDefaultContext) -> Double {
        guard vm.selectedNode != nil else { return 0.0 }
        return timeline.date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 2.0) / 2.0
    }
}

// MARK: - Hover tooltip

private struct HoverTooltip: View {
    let node: FSNode

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: FileTypeIcon.systemName(for: node))
                .foregroundStyle(FileTypeIcon.color(for: node))
                .font(.system(size: 20))
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(node.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Label(ByteFormatter.string(from: node.size), systemImage: "internaldrive")
                        .monospacedDigit()
                    if node.isDirectory {
                        Label("\(node.children.count) items", systemImage: "folder")
                    } else if !node.fileExtension.isEmpty {
                        Text(".\(node.fileExtension.uppercased())")
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
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
        .padding(.vertical, 9)
        .frame(maxWidth: 380)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 5)
    }
}
