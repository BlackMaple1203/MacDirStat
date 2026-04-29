import SwiftUI

struct ExtensionListView: View {
    @EnvironmentObject private var vm: ScanViewModel
    @State private var selectedExt: String?

    var body: some View {
        Table(vm.extensionSummaries, selection: $selectedExt) {
            TableColumn("") { item in
                RoundedRectangle(cornerRadius: 3)
                    .fill(item.color)
                    .frame(width: 14, height: 14)
            }
            .width(20)

            TableColumn("Extension") { item in
                Text(item.ext)
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 80, ideal: 100)

            TableColumn("Files") { item in
                Text("\(item.fileCount)")
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(60)

            TableColumn("Size") { item in
                Text(ByteFormatter.string(from: item.totalSize))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(80)

            TableColumn("%") { item in
                HStack(spacing: 6) {
                    GeometryReader { g in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(item.color.opacity(0.4))
                            .frame(width: g.size.width * item.percentage / 100)
                    }
                    .frame(height: 6)
                    Text(String(format: "%.1f%%", item.percentage))
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }
            }
            .width(min: 100, ideal: 140)
        }
        .onChange(of: selectedExt) { _, ext in
            vm.highlight(extension: ext)
        }
    }
}
