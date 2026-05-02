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
        HStack(spacing: 6) {
            // Icon
            Image(systemName: FileTypeIcon.systemName(for: node))
                .foregroundStyle(FileTypeIcon.color(for: node))
                .font(.system(size: 12))
                .frame(width: 14, alignment: .center)

            // Name — takes all available space, tail-truncated
            Text(node.name)
                .font(.system(size: 12.5))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isSelected ? .white : .primary)

            // Inline extension badge for files
            if !node.isDirectory, !node.fileExtension.isEmpty {
                Text(node.fileExtension.uppercased())
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.65) : Color.secondary.opacity(0.5))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1.5)
                    .background(
                        isSelected ? Color.white.opacity(0.15) : Color.primary.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 3)
                    )
                    .fixedSize()
            }

            Spacer(minLength: 4)

            // Size
            Text(ByteFormatter.string(from: node.size))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(isSelected ? Color.white.opacity(0.9) : .primary)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()

            // Percentage of parent — fixed width so sizes stay aligned
            Text(percentageOfParent ?? "")
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? Color.white.opacity(0.55) : Color.secondary.opacity(0.65))
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
                .lineLimit(1)
                .opacity(percentageOfParent == nil ? 0 : 1)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            isSelected ? Color.accentColor.opacity(0.85) : Color.clear,
            in: RoundedRectangle(cornerRadius: 5)
        )
    }

    private var percentageOfParent: String? {
        guard let parentSize = node.parent?.size, parentSize > 0 else { return nil }
        let pct = Double(node.size) / Double(parentSize) * 100
        return pct >= 10 ? String(format: "%.0f%%", pct) : String(format: "%.1f%%", pct)
    }
}
