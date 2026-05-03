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
        .navigationTitle("")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                if activeTab == .treemap, vm.root != nil || vm.isScanning {
                    Button { vm.drillUp() } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(vm.drillStack.isEmpty)

                    if let node = vm.treemapRoot {
                        FolderTitleView(url: node.url)
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
        // 2-pt inset padding so the active pill has breathing room from the outer rail
        HStack(spacing: 2) {
            tabButton(tab: .treemap,    icon: "square.3.layers.3d", label: "Treemap")
            tabButton(tab: .duplicates, icon: "doc.on.doc",          label: "Duplicates",
                      badge: duplicatesBadge, detecting: !vm.duplicatesReady && vm.root != nil)
        }
        .padding(2)
        .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
        .fixedSize()
    }

    private var duplicatesBadge: String? {
        guard vm.duplicatesReady, !vm.isScanning else { return nil }
        let n = vm.duplicateGroups.count
        return n > 0 ? "\(n)" : nil
    }

    @ViewBuilder
    private func tabButton(
        tab: DetailTab,
        icon: String,
        label: String,
        badge: String? = nil,
        detecting: Bool = false
    ) -> some View {
        let isActive = activeTab == tab

        Button {
            withAnimation(.easeInOut(duration: 0.16)) { activeTab = tab }
        } label: {
            HStack(spacing: 5) {
                // Fixed-size icon slot so width never jumps when spinner appears
                ZStack {
                    if detecting {
                        ProgressView().controlSize(.mini).scaleEffect(0.8)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .frame(width: 14, height: 14)

                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .fixedSize()

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.orange, in: Capsule())
                        .fixedSize()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                isActive
                    ? AnyShapeStyle(.background.shadow(.drop(color: .black.opacity(0.12), radius: 1, y: 1)))
                    : AnyShapeStyle(Color.clear),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .foregroundStyle(isActive ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(tab == .duplicates && vm.root == nil && !detecting)
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

// MARK: - Folder title (compact — name + one parent level)

private struct FolderTitleView: View {
    let url: URL

    private var name: String { url.lastPathComponent }
    private var parent: String? {
        let p = url.deletingLastPathComponent().lastPathComponent
        return (p.isEmpty || p == "/") ? nil : p
    }

    var body: some View {
        HStack(spacing: 4) {
            if let parent {
                Text(parent)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .lineLimit(1)
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
