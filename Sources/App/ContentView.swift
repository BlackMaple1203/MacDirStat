import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vm: ScanViewModel

    var body: some View {
        HSplitView {
            SidebarView()
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 320)

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
                Button(action: { vm.drillUp() }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(vm.drillStack.isEmpty)

                if let node = vm.treemapRoot {
                    Text(node.url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if vm.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Button("Cancel") { vm.cancelScan() }
                        .foregroundStyle(.red)
                } else {
                    Button("Open Folder…") { openFolderPicker(vm: vm) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportCSV)) { _ in
            vm.exportCSV()
        }
    }
}

extension Notification.Name {
    static let exportCSV = Notification.Name("MacDirStat.exportCSV")
}

private func openFolderPicker(vm: ScanViewModel) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = "Scan"
    if panel.runModal() == .OK, let url = panel.url {
        Task { @MainActor in vm.scan(url: url) }
    }
}
