import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vm: ScanViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    /// Persisted user preference — survives relaunches and drill actions.
    @AppStorage("showFileTree") private var userWantsTree = true
    /// True only while an initial scan is running (temporary, never persisted).
    @State private var scanHidesTree = false

    private var showTree: Bool { userWantsTree && !scanHidesTree }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            detailContent
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first, url.hasDirectoryPath else { return false }
            vm.scan(url: url)
            return true
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                if vm.root != nil || vm.isScanning {
                    Button { vm.drillUp() } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(vm.drillStack.isEmpty)

                    if let node = vm.treemapRoot {
                        BreadcrumbView(url: node.url)
                    }
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                // Tree panel toggle — only show when there's something to display
                if vm.root != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { userWantsTree.toggle() }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .symbolVariant(showTree ? .none : .slash)
                    }
                    .help(showTree ? "Hide file list" : "Show file list")
                }

                if vm.isScanning || vm.isComputingLayout {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        if vm.isScanning {
                            Text("\(vm.itemsScanned) items")
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            Text(ByteFormatter.string(from: vm.bytesFound))
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            Button("Cancel") { vm.cancelScan() }
                                .foregroundStyle(.red)
                        } else {
                            Text("Building treemap…")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .transition(.opacity)
                } else {
                    Button("Open Folder…") { openFolderPicker(vm: vm) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        // Temporarily hide tree while scanning; restore to user preference when done.
        // Does NOT touch the scan when drilling — layout recomputes don't reset the panel.
        .onChange(of: vm.isScanning) { _, scanning in
            withAnimation(.easeInOut(duration: 0.2)) { scanHidesTree = scanning }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.isScanning || vm.isComputingLayout)
        .onReceive(NotificationCenter.default.publisher(for: .exportCSV)) { _ in
            vm.exportCSV()
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if vm.root == nil && !vm.isScanning && !vm.isComputingLayout {
            WelcomeView()
        } else {
            VStack(spacing: 0) {
                if showTree {
                    HSplitView {
                        DirectoryTreeView()
                            .frame(minWidth: 220, idealWidth: 300)
                        TreemapView()
                            .frame(minWidth: 300)
                    }
                } else {
                    TreemapView()
                }

                Divider()
                ExtensionListView()
                    .frame(height: 84)
            }
        }
    }
}

// MARK: - Welcome screen

private struct WelcomeView: View {
    @EnvironmentObject private var vm: ScanViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: 72, weight: .thin))
                .foregroundStyle(.quaternary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("MacDirStat")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Visualize your disk space usage at a glance")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Button("Open Folder…") { openFolderPicker(vm: vm) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("o", modifiers: .command)

            Text("Or drop a folder anywhere in this window")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Breadcrumb

private struct BreadcrumbView: View {
    let url: URL

    private var parts: [String] { url.pathComponents.filter { $0 != "/" } }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                    if i > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    Text(part)
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(i == parts.count - 1 ? .primary : .secondary)
                        .fontWeight(i == parts.count - 1 ? .medium : .regular)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: 380)
    }
}

// MARK: - Helpers

extension Notification.Name {
    static let exportCSV = Notification.Name("MacDirStat.exportCSV")
}

@MainActor
private func openFolderPicker(vm: ScanViewModel) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = "Scan"
    if panel.runModal() == .OK, let url = panel.url {
        vm.scan(url: url)
    }
}
