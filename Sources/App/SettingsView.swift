import SwiftUI

struct SettingsView: View {
    @AppStorage("hapticFeedbackEnabled") private var hapticEnabled = true

    var body: some View {
        Form {
            Section("Trackpad") {
                Toggle("Haptic feedback", isOn: $hapticEnabled)
                Text("Feel the weight of files and folders as you explore the chart. Requires a Force Touch trackpad.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding(.vertical, 8)
    }
}
