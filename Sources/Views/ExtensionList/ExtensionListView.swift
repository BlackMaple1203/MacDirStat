import SwiftUI
struct ExtensionListView: View {
    @EnvironmentObject private var vm: ScanViewModel
    var body: some View { Text("Extensions").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
