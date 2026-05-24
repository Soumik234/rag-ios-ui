import SwiftUI

extension View {
    func glassCard(cornerRadius: CGFloat = 16, material: Material = .ultraThin) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, material: material, tint: .clear))
    }

    func glassCard(cornerRadius: CGFloat = 16, material: Material = .ultraThin, tint: Color) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, material: material, tint: tint))
    }
}

private struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let material: Material
    let tint: Color

    func body(content: Content) -> some View {
        content
            // Native Material creates the glass blur and enables vibrancy for hierarchical foreground styles.
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.34), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
    }
}
