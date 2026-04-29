import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var vm: ScanViewModel
    @State private var volumes: [URL] = []
    @AppStorage("recentPaths") private var recentPathsData: Data = Data()

    private var recentPaths: [URL] {
        (try? JSONDecoder().decode([String].self, from: recentPathsData))
            .map { $0.compactMap { URL(fileURLWithPath: $0) } } ?? []
    }

    var body: some View {
        List {
            Section("Volumes") {
                ForEach(volumes, id: \.path) { vol in
                    VolumeRow(url: vol)
                        .onTapGesture { vm.scan(url: vol) }
                }
            }

            Section("Recent") {
                ForEach(recentPaths, id: \.path) { url in
                    Label(url.lastPathComponent, systemImage: "folder")
                        .foregroundStyle(.primary)
                        .onTapGesture { vm.scan(url: url) }
                }
            }

            if vm.duplicatesReady {
                Section("Analysis") {
                    NavigationLink {
                        DuplicatesView()
                    } label: {
                        Label("Duplicates", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onAppear { volumes = mountedVolumes() }
        .onChange(of: vm.root?.url) { _, url in
            guard let url else { return }
            addRecent(url: url)
        }
    }

    private func mountedVolumes() -> [URL] {
        FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey, .volumeIsRemovableKey],
            options: [.skipHiddenVolumes]
        ) ?? []
    }

    private func addRecent(url: URL) {
        var paths = recentPaths.map(\.path)
        paths.removeAll { $0 == url.path }
        paths.insert(url.path, at: 0)
        let trimmed = Array(paths.prefix(10))
        recentPathsData = (try? JSONEncoder().encode(trimmed)) ?? Data()
    }
}

private struct VolumeRow: View {
    let url: URL

    var body: some View {
        HStack {
            Image(systemName: volumeIcon)
                .foregroundStyle(.blue)
            VStack(alignment: .leading) {
                Text(volumeName)
                    .font(.callout)
                if let total = totalSpace, let free = freeSpace {
                    Text("\(ByteFormatter.string(from: free)) free of \(ByteFormatter.string(from: total))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var volumeName: String {
        (try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? url.lastPathComponent
    }

    private var volumeIcon: String {
        let isRemovable = (try? url.resourceValues(forKeys: [.volumeIsRemovableKey]).volumeIsRemovable) ?? false
        return isRemovable ? "externaldrive" : "internaldrive"
    }

    private var totalSpace: Int64? {
        (try? url.resourceValues(forKeys: [.volumeTotalCapacityKey]).volumeTotalCapacity).map { Int64($0) }
    }

    private var freeSpace: Int64? {
        (try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity).map { Int64($0) }
    }
}
