import SwiftUI

struct DuplicatesView: View {
    @EnvironmentObject private var vm: ScanViewModel

    var body: some View {
        let groups = vm.duplicateGroups
        if groups.isEmpty {
            ContentUnavailableView("No Duplicates Found",
                systemImage: "checkmark.circle",
                description: Text("No duplicate files were detected"))
        } else {
            VStack(spacing: 0) {
                summaryBar(groups: groups)
                Divider()
                List {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        DuplicateGroupRow(group: group)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    @ViewBuilder
    private func summaryBar(groups: [[FSNode]]) -> some View {
        let totalWasted = groups.reduce(Int64(0)) { $0 + $1[0].size * Int64($1.count - 1) }
        let totalFiles = groups.reduce(0) { $0 + $1.count - 1 }

        HStack(spacing: 16) {
            Label("\(groups.count) groups", systemImage: "square.on.square")
                .font(.caption).foregroundStyle(.secondary)
            Label("\(totalFiles) duplicate files", systemImage: "doc.on.doc")
                .font(.caption).foregroundStyle(.secondary)
            Label(ByteFormatter.string(from: totalWasted) + " wasted", systemImage: "externaldrive.badge.minus")
                .font(.caption).foregroundStyle(.orange)
            Spacer()
            Button(role: .destructive) {
                deleteAll(groups: groups)
            } label: {
                Label("Delete All Duplicates", systemImage: "trash")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.85))
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func deleteAll(groups: [[FSNode]]) {
        guard let rootURL = vm.root?.url else { return }
        var deleted = false
        for group in groups {
            for node in group.dropFirst() {
                if (try? FileManager.default.trashItem(at: node.url, resultingItemURL: nil)) != nil {
                    deleted = true
                }
            }
        }
        if deleted { vm.scan(url: rootURL) }
    }
}

// MARK: - Group Row

private struct DuplicateGroupRow: View {
    @EnvironmentObject private var vm: ScanViewModel
    let group: [FSNode]
    @State private var isExpanded = true

    private var wasted: Int64 { group[0].size * Int64(group.count - 1) }

    var body: some View {
        Section(isExpanded: $isExpanded) {
            ForEach(Array(group.enumerated()), id: \.element.id) { index, node in
                FileRow(node: node, isKeep: index == 0, onDelete: {
                    deleteNode(node)
                })
            }
        } header: {
            groupHeader
        }
    }

    @ViewBuilder
    private var groupHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 11))
                .foregroundStyle(.orange)

            Text("\(group.count) identical copies")
                .fontWeight(.semibold)
                .font(.system(size: 12))

            Text("·")
                .foregroundStyle(.tertiary)

            Text(ByteFormatter.string(from: wasted) + " wasted")
                .font(.system(size: 12))
                .foregroundStyle(.orange)

            Spacer()

            Button(role: .destructive) {
                deleteGroup()
            } label: {
                Label("Keep 1, Delete \(group.count - 1)", systemImage: "trash")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .tint(.red)
        }
        .padding(.vertical, 2)
    }

    private func deleteGroup() {
        guard let rootURL = vm.root?.url else { return }
        var deleted = false
        for node in group.dropFirst() {
            if (try? FileManager.default.trashItem(at: node.url, resultingItemURL: nil)) != nil {
                deleted = true
            }
        }
        if deleted { vm.scan(url: rootURL) }
    }

    private func deleteNode(_ node: FSNode) {
        guard let rootURL = vm.root?.url else { return }
        if (try? FileManager.default.trashItem(at: node.url, resultingItemURL: nil)) != nil {
            vm.scan(url: rootURL)
        }
    }
}

// MARK: - File Row

private struct FileRow: View {
    @EnvironmentObject private var vm: ScanViewModel
    let node: FSNode
    let isKeep: Bool
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Keep / duplicate badge
            if isKeep {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
                    .help("This copy will be kept")
            } else {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(node.name)
                    .font(.system(size: 12.5))
                    .lineLimit(1)
                Text(node.url.deletingLastPathComponent().path)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            Text(ByteFormatter.string(from: node.size))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            // Trash button — always visible for duplicates, hidden for keep
            if isKeep {
                Color.clear.frame(width: 24, height: 24)
            } else {
                Button(action: onDelete) {
                    Image(systemName: isHovered ? "trash.fill" : "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(isHovered ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .onHover { isHovered = $0 }
                .help("Move to Trash")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([node.url])
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(node.url.path, forType: .string)
            }
            if !isKeep {
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label("Move to Trash", systemImage: "trash")
                }
            }
        }
    }
}
