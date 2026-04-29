import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vm: ScanViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            VStack(spacing: 0) {
                HSplitView {
                    DirectoryTreeView()
                        .frame(minWidth: 240, idealWidth: 320)
                    TreemapView()
                        .frame(minWidth: 300)
                }
                Divider()
                ExtensionListView()
                    .frame(minHeight: 120, idealHeight: 180, maxHeight: 280)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first, url.hasDirectoryPath else { return false }
            Task { @MainActor in vm.scan(url: url) }
            return true
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { vm.drillUp() } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(vm.drillStack.isEmpty)
                .help("Go up one level")

                if let node = vm.treemapRoot {
                    BreadcrumbView(url: node.url)
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if vm.isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("\(vm.itemsScanned) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .transition(.opacity)
                        Button("Cancel") { vm.cancelScan() }
                            .foregroundStyle(.red)
                    }
                    .transition(.opacity)
                } else {
                    Button { openFolderPicker(vm: vm) } label: {
                        Label("Open Folder…", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Choose a folder to scan (⌘O)")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportCSV)) { _ in
            vm.exportCSV()
        }
        .animation(.easeInOut(duration: 0.2), value: vm.isScanning)
    }
}

private struct BreadcrumbView: View {
    let url: URL

    private var parts: [String] {
        url.pathComponents.filter { $0 != "/" }
    }

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
        .frame(maxWidth: 400)
    }
}

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
