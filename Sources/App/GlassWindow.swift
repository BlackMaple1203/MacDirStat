import SwiftUI
import AppKit

/// Configures the hosting NSWindow to be fully transparent so VibrancyBackground
/// can render the blurred desktop effect behind all content.
private struct GlassWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Full-bleed NSVisualEffectView that blurs desktop content behind the window.
struct VibrancyBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

extension View {
    /// Makes the window transparent and fills it with adaptive desktop vibrancy —
    /// the foundation of the Liquid Glass look.
    func glassWindow(material: NSVisualEffectView.Material = .underWindowBackground) -> some View {
        background(
            VibrancyBackground(material: material)
                .ignoresSafeArea()
                .overlay(GlassWindowConfigurator().frame(width: 0, height: 0))
        )
    }
}
