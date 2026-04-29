import SwiftUI
struct DirectoryTreeView: View {
    @EnvironmentObject private var vm: ScanViewModel
    var body: some View { Text("Directory Tree").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
