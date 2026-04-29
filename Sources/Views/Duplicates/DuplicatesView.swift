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
            List {
                ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                    Section {
                        ForEach(group) { node in
                            HStack {
                                Image(systemName: "doc")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading) {
                                    Text(node.name)
                                    Text(node.url.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Text(ByteFormatter.string(from: node.size))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .contextMenu {
                                Button("Reveal in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([node.url])
                                }
                                Button("Copy Path") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(node.url.path, forType: .string)
                                }
                            }
                        }
                    } header: {
                        let wasted = group[0].size * Int64(group.count - 1)
                        HStack {
                            Text("Group \(index + 1)")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(group.count) copies · \(ByteFormatter.string(from: wasted)) wasted")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}
