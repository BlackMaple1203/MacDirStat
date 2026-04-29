import SwiftUI

@main
struct MacDirStatApp: App {
    @StateObject private var vm = ScanViewModel()

    var body: some Scene {
        WindowGroup("MacDirStat") {
            ContentView()
                .environmentObject(vm)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") {
                    openFolderPicker(vm: vm)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Export CSV…") {
                    NotificationCenter.default.post(name: NSNotification.Name("MacDirStat.exportCSV"), object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}

private func openFolderPicker(vm: ScanViewModel) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = "Scan"
    panel.message = "Choose a folder to analyze"
    if panel.runModal() == .OK, let url = panel.url {
        Task { @MainActor in vm.scan(url: url) }
    }
}
