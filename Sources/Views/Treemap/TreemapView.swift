import SwiftUI
struct TreemapView: View {
    @EnvironmentObject private var vm: ScanViewModel
    var body: some View { Text("Treemap").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
