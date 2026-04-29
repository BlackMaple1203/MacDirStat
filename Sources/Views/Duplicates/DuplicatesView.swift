import SwiftUI
struct DuplicatesView: View {
    @EnvironmentObject private var vm: ScanViewModel
    var body: some View { Text("Duplicates").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
