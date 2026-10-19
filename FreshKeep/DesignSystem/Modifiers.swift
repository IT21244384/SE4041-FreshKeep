import SwiftUI

// MARK: - Card

/// Custom view modifier: the rounded, softly shadowed card used across the app.
struct FreshCardModifier: ViewModifier {
    var padding: CGFloat = Spacing.l
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 10, y: 4)
    }
}

extension View {
    func freshCard(padding: CGFloat = Spacing.l) -> some View {
        modifier(FreshCardModifier(padding: padding))
    }
}

// MARK: - Buttons

/// Big gradient call-to-action that squashes slightly when pressed.
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = .brand
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(.headline, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, Spacing.l)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappySpring, value: configuration.isPressed)
    }
}

/// Tinted secondary button.
struct SoftButtonStyle: ButtonStyle {
    var tint: Color = .brand

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(.subheadline, weight: .semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, Spacing.m)
            .background(tint.opacity(configuration.isPressed ? 0.22 : 0.12),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappySpring, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SoftButtonStyle {
    static var soft: SoftButtonStyle { SoftButtonStyle() }
    static func soft(_ tint: Color) -> SoftButtonStyle { SoftButtonStyle(tint: tint) }
}

// MARK: - Filter chip

struct FilterChip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                if let systemImage { Image(systemName: systemImage) }
            }
            .font(.rounded(.subheadline, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? AnyShapeStyle(Color.brand.gradient) : AnyShapeStyle(Color.cardBackground),
                        in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(isSelected ? 0 : 0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Shake

/// Geometry effect used to shake a field when validation fails.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 8
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * shakes), y: 0))
    }
}
