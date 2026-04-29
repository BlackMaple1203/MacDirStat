import SwiftUI

struct DirectoryTreeView: View {
    @EnvironmentObject private var vm: ScanViewModel

    var body: some View {
        if let root = vm.root {
            List(root.children.sorted { $0.size > $1.size }, children: \.optionalChildren) { node in
                HStack {
                    Image(systemName: node.isDirectory ? "folder.fill" : "doc")
                        .foregroundStyle(node.isDirectory ? .yellow : .secondary)
                    Text(node.name)
                    Spacer()
                    Text(ByteFormatter.string(from: node.size))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if let parentSize = node.parent?.size, parentSize > 0 {
                        Text(String(format: "%.1f%%", Double(node.size) / Double(parentSize) * 100))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                            .frame(width: 55)
                    }
                }
            }
        } else if vm.isScanning {
            VStack(spacing: 12) {
                ProgressView()
                Text("Scanning… \(vm.itemsScanned) items")
                    .foregroundStyle(.secondary)
                Text(ByteFormatter.string(from: vm.bytesFound) + " found")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView("No Folder Selected",
                systemImage: "folder.badge.questionmark",
                description: Text("Open a folder to analyze its disk usage"))
        }
    }
}
