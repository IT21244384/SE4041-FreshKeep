import SwiftUI
import FreshKeepCore

/// FreshKeep brand palette. Every colour lives in the asset catalog with a
/// light and dark variant, so Dark Mode works automatically.
extension Color {
    static let brand = Color("Brand")
    static let brandDeep = Color("BrandDeep")
    static let citrus = Color("Citrus")
    static let cardBackground = Color("CardBackground")
    static let appBackground = Color("AppBackground")

    static func freshness(_ level: FreshnessLevel) -> Color {
        Color(level.colorName)
    }
}

extension ShapeStyle where Self == LinearGradient {
    /// Signature leaf-green gradient used on hero areas and primary buttons.
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [Color("Brand"), Color("BrandDeep")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Font {
    /// Rounded type keeps the friendly tone while still scaling with Dynamic Type.
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}

/// Shorter, consistent animation curves.
extension Animation {
    static let snappySpring = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let gentleSpring = Animation.spring(response: 0.6, dampingFraction: 0.8)
}
