import SwiftUI
struct SidebarView: View {
    @EnvironmentObject private var vm: ScanViewModel
    var body: some View { Text("Sidebar").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
