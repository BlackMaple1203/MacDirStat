import SwiftUI

struct DirectoryTreeView: View {
    @EnvironmentObject private var vm: ScanViewModel

    var body: some View {
        Group {
            if let root = vm.root {
                List(root.children.sorted { $0.size > $1.size }, children: \.optionalChildren) { node in
                    NodeRow(node: node)
                        .onTapGesture { vm.select(node) }
                        .contextMenu {
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([node.url])
                            }
                            Button("Copy Path") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(node.url.path, forType: .string)
                            }
                            Divider()
                            Button("Move to Trash", role: .destructive) {
                                if let _ = try? FileManager.default.trashItem(at: node.url, resultingItemURL: nil),
                                   let root = vm.root {
                                    vm.scan(url: root.url)
                                }
                            }
                        }
                }
                .listStyle(.inset)
            } else if vm.isScanning {
                ScanningPlaceholder(items: vm.itemsScanned, bytes: vm.bytesFound)
            } else {
                ContentUnavailableView(
                    "No Folder Selected",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Drag a folder here or click Open Folder")
                )
            }
        }
    }
}

private struct ScanningPlaceholder: View {
    let items: Int
    let bytes: Int64

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
            VStack(spacing: 4) {
                Text("Scanning…")
                    .font(.headline)
                Text("\(items) items · \(ByteFormatter.string(from: bytes))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut, value: items)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NodeRow: View {
    let node: FSNode

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: FileTypeIcon.systemName(for: node))
                .foregroundStyle(FileTypeIcon.color(for: node))
                .font(.system(size: 14))
                .frame(width: 18, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(node.name)
                    .font(.body)
                    .lineLimit(1)

                if !node.isDirectory, !node.fileExtension.isEmpty {
                    Text(".\(node.fileExtension)".uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(ByteFormatter.string(from: node.size))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                if let pct = percentageOfParent {
                    Text(pct)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var percentageOfParent: String? {
        guard let parentSize = node.parent?.size, parentSize > 0 else { return nil }
        return String(format: "%.1f%%", Double(node.size) / Double(parentSize) * 100)
    }
}
