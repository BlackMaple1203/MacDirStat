import SwiftUI

// Compatibility shims for macOS 26 Liquid Glass and macOS 14/15 APIs.
// On older OS versions these fall back to NSVisualEffectView-based materials.

extension View {
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }

    @ViewBuilder
    func glassCircle() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: .circle)
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }

    @ViewBuilder
    func glassCard(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func glassInteractiveCard(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func glassTintedCard(tint: Color, cornerRadius: CGFloat) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func glassTintedInteractiveCapsule(tint: Color) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }

    @ViewBuilder
    func glassButton() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func glassProminentButton() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - ContentUnavailableView backport

struct CompatContentUnavailableView: View {
    let title: String
    let systemImage: String
    let description: Text

    var body: some View {
        if #available(macOS 14, *) {
            ContentUnavailableView(title, systemImage: systemImage, description: description)
        } else {
            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.title3.weight(.semibold))
                description
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}
