import SwiftUI

/// Vera's design tokens. One source of truth for spacing, radii, and brand colour
/// so screens stay consistent and uncramped. See DESIGN.md for the rationale.
enum Theme {
    /// 4-pt based spacing scale. Use these instead of ad-hoc numbers.
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    /// Corner radii for cards, tiles, and prominent controls.
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 20
    }

    /// Brand teal. `accent` follows the asset-catalog AccentColor (used app-wide for
    /// tints); `brand` is the saturated fill used for hero marks (onboarding icon).
    static let accent = Color.accentColor
    static let brand = Color("BrandTeal")
}
