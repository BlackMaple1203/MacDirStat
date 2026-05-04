import SwiftUI

enum DetailTab { case treemap, duplicates }

struct ContentView: View {
    @EnvironmentObject private var vm: ScanViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @AppStorage("showFileTree") private var userWantsTree = true
    @State private var scanHidesTree = false
    @State private var activeTab: DetailTab = .treemap
    @Namespace private var tabNamespace

    private var showTree: Bool { userWantsTree && !scanHidesTree }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            detailContent
        }
        .glassWindow()
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(in: .capsule)
                    .transition(.opacity)
                } else {
                    Button("Open Folder…") { openFolderPicker(vm: vm) }
                        .buttonStyle(.glassProminent)
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
            tabButton(tab: .treemap,    icon: "square.3.layers.3d", label: "Treemap")
            tabButton(tab: .duplicates, icon: "doc.on.doc",          label: "Duplicates",
                      badge: duplicatesBadge, detecting: !vm.duplicatesReady && vm.root != nil)
        }
        .padding(3)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
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
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { activeTab = tab }
        } label: {
            HStack(spacing: 5) {
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
            .padding(.vertical, 5)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(.primary.opacity(0.12))
                        .matchedGeometryEffect(id: "tabHighlight", in: tabNamespace)
                }
            }
            .foregroundStyle(isActive ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(tab == .duplicates && vm.root == nil && !detecting)
    }

    // MARK: - Detail content

    @ViewBuilder
    private var detailContent: some View {
        VStack(spacing: 0) {
            if !vm.hasFullDiskAccess {
                FullDiskAccessBanner()
            }
            if vm.root == nil && !vm.isScanning && !vm.isComputingLayout {
                WelcomeView()
            } else if activeTab == .duplicates {
                duplicatesContent
            } else {
                treemapContent
            }
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
            .padding(32)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            DuplicatesView()
        }
    }
}

// MARK: - Welcome screen

private struct WelcomeView: View {
    @EnvironmentObject private var vm: ScanViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var animate = false

    private var isDark: Bool { colorScheme == .dark }

    // Dark mode: deep indigo/violet. Light mode: soft lavender/periwinkle pastels.
    private var gradientColors: [Color] {
        isDark ? [
            Color(hue: 0.67, saturation: 0.65, brightness: 0.28),
            Color(hue: 0.72, saturation: 0.75, brightness: 0.22),
            Color(hue: 0.62, saturation: 0.55, brightness: 0.32),
            Color(hue: 0.70, saturation: 0.70, brightness: 0.26),
            Color(hue: 0.65, saturation: 0.60, brightness: 0.38),
            Color(hue: 0.75, saturation: 0.65, brightness: 0.28),
            Color(hue: 0.62, saturation: 0.50, brightness: 0.24),
            Color(hue: 0.68, saturation: 0.75, brightness: 0.28),
            Color(hue: 0.72, saturation: 0.65, brightness: 0.26)
        ] : [
            Color(hue: 0.67, saturation: 0.28, brightness: 0.97),
            Color(hue: 0.72, saturation: 0.22, brightness: 0.99),
            Color(hue: 0.60, saturation: 0.20, brightness: 0.98),
            Color(hue: 0.70, saturation: 0.25, brightness: 0.96),
            Color(hue: 0.65, saturation: 0.18, brightness: 1.00),
            Color(hue: 0.75, saturation: 0.22, brightness: 0.97),
            Color(hue: 0.62, saturation: 0.20, brightness: 0.98),
            Color(hue: 0.68, saturation: 0.28, brightness: 0.95),
            Color(hue: 0.72, saturation: 0.22, brightness: 0.97)
        ]
    }

    var body: some View {
        ZStack {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    .init(0, 0), .init(0.5, 0), .init(1, 0),
                    .init(0, 0.5), animate ? .init(0.55, 0.42) : .init(0.45, 0.58), .init(1, 0.5),
                    .init(0, 1), .init(0.5, 1), .init(1, 1)
                ],
                colors: gradientColors
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: animate)

            VStack(spacing: 32) {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 80, weight: .thin))
                    .foregroundStyle(.primary.opacity(0.85))
                    .symbolRenderingMode(.hierarchical)
                    .padding(24)
                    .glassEffect(in: .circle)

                VStack(spacing: 10) {
                    Text("MacDirStat")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Visualize your disk space usage at a glance")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Open Folder…") { openFolderPicker(vm: vm) }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .keyboardShortcut("o", modifiers: .command)

                Text("Or drop a folder anywhere")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassEffect(in: .capsule)
            }
            .padding(48)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { animate = true }
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
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .glassEffect(in: .capsule)
    }
}

// MARK: - Full Disk Access banner

private struct FullDiskAccessBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 1) {
                Text("Full Disk Access required for complete results")
                    .font(.system(size: 12, weight: .semibold))
                Text("Go to System Settings → Privacy & Security → Full Disk Access and add MacDirStat.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Open Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            }
            .font(.system(size: 11, weight: .medium))
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.orange.opacity(0.15))
        .overlay(alignment: .bottom) { Divider().overlay(.orange.opacity(0.3)) }
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
