import SwiftUI

enum DetailTab { case treemap, duplicates }

struct ContentView: View {
    @EnvironmentObject private var vm: ScanViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @AppStorage("showFileTree") private var userWantsTree = true
    @State private var scanHidesTree = false
    @State private var activeTab: DetailTab = .treemap

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
                if activeTab == .treemap, vm.root != nil || vm.isScanning {
                    Button { vm.drillUp() } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(vm.drillStack.isEmpty)

                    if let node = vm.treemapRoot {
                        BreadcrumbView(url: node.url)
                    }
                }
            }

            // Tab switcher — center of toolbar
            ToolbarItem(placement: .principal) {
                if vm.root != nil || vm.isScanning || vm.isComputingLayout {
                    tabPicker
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if activeTab == .treemap {
                    if vm.root != nil {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { userWantsTree.toggle() }
                        } label: {
                            Image(systemName: "sidebar.left")
                                .symbolVariant(showTree ? .none : .slash)
                        }
                        .help(showTree ? "Hide file list" : "Show file list")
                    }
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
        .onChange(of: vm.isScanning) { _, scanning in
            withAnimation(.easeInOut(duration: 0.2)) { scanHidesTree = scanning }
            // Return to treemap tab when a new scan starts
            if scanning { withAnimation { activeTab = .treemap } }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.isScanning || vm.isComputingLayout)
        .onReceive(NotificationCenter.default.publisher(for: .exportCSV)) { _ in
            vm.exportCSV()
        }
    }

    // MARK: - Tab picker

    @ViewBuilder
    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(tab: .treemap, icon: "square.3.layers.3d", label: "Treemap")
            tabButton(tab: .duplicates, icon: "doc.on.doc", label: duplicatesLabel, badge: duplicatesBadge)
        }
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.08)))
    }

    private var duplicatesLabel: String { "Duplicates" }

    private var duplicatesBadge: String? {
        if vm.isScanning { return nil }
        if !vm.duplicatesReady { return nil }
        let count = vm.duplicateGroups.count
        return count > 0 ? "\(count)" : nil
    }

    @ViewBuilder
    private func tabButton(tab: DetailTab, icon: String, label: String, badge: String? = nil) -> some View {
        let isActive = activeTab == tab
        let isDetecting = tab == .duplicates && !vm.duplicatesReady && vm.root != nil

        Button {
            withAnimation(.easeInOut(duration: 0.18)) { activeTab = tab }
        } label: {
            HStack(spacing: 5) {
                if isDetecting {
                    ProgressView().controlSize(.mini).frame(width: 13, height: 13)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(label)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(.orange, in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? Color.primary.opacity(0.10) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(isActive ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(tab == .duplicates && vm.root == nil)
    }

    // MARK: - Detail content

    @ViewBuilder
    private var detailContent: some View {
        if vm.root == nil && !vm.isScanning && !vm.isComputingLayout {
            WelcomeView()
        } else if activeTab == .duplicates {
            duplicatesContent
        } else {
            treemapContent
        }
    }

    @ViewBuilder
    private var treemapContent: some View {
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

    @ViewBuilder
    private var duplicatesContent: some View {
        if vm.root != nil && !vm.duplicatesReady {
            VStack(spacing: 16) {
                ProgressView()
                Text("Scanning for duplicates…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("This runs in the background — it may take a moment for large folders.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            DuplicatesView()
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
