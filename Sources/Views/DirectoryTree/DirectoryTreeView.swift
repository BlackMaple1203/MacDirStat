import SwiftUI

struct DirectoryTreeView: View {
    @EnvironmentObject private var vm: ScanViewModel

    var body: some View {
        Group {
            if let root = vm.root {
                List(root.children.sorted { $0.size > $1.size }, children: \.optionalChildren) { node in
                    NodeRow(node: node, isSelected: vm.selectedNode?.id == node.id)
                        .contentShape(Rectangle())
                        .onTapGesture { vm.select(node) }
                        .contextMenu {
                            Text(node.name).fontWeight(.semibold)
                            Text(ByteFormatter.string(from: node.size))
                                .foregroundStyle(.secondary)
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
                                    vm.drillDown(into: node)
                                } label: {
                                    Label("Open in Chart", systemImage: "arrow.down.right.circle")
                                }
                            }
                            Divider()
                            Button(role: .destructive) {
                                if let _ = try? FileManager.default.trashItem(at: node.url, resultingItemURL: nil),
                                   let root = vm.root {
                                    vm.scan(url: root.url)
                                }
                            } label: {
                                Label("Move to Trash", systemImage: "trash")
                            }
                        }
                }
                .listStyle(.inset)
            } else {
                ScanningPlaceholder(items: vm.itemsScanned, bytes: vm.bytesFound)
            }
        }
    }
}

private struct ScanningPlaceholder: View {
    let items: Int
    let bytes: Int64

    var body: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.3)
            VStack(spacing: 4) {
                Text("Scanning…").font(.headline)
                Text("\(items) items · \(ByteFormatter.string(from: bytes))")
                    .font(.subheadline).foregroundStyle(.secondary)
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
    let isSelected: Bool

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
                    .foregroundStyle(isSelected ? .white : .primary)

                if !node.isDirectory, !node.fileExtension.isEmpty {
                    Text(".\(node.fileExtension)".uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.75) : Color.secondary.opacity(0.6))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            isSelected ? Color.white.opacity(0.20) : Color.gray.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 3)
                        )
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(ByteFormatter.string(from: node.size))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .monospacedDigit()

                if let pct = percentageOfParent {
                    Text(pct)
                        .font(.caption2)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.75) : Color.secondary.opacity(0.6))
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.85)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    private var percentageOfParent: String? {
        guard let parentSize = node.parent?.size, parentSize > 0 else { return nil }
        return String(format: "%.1f%%", Double(node.size) / Double(parentSize) * 100)
    }
}
