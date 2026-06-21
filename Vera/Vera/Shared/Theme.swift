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

    /// Typography. Vera leans on the system text styles (Dynamic Type, no bundled
    /// faces) for one consistent, accessible ramp; the signature is the monospace.
    ///
    /// **UI type ramp** (semantic, scales with Dynamic Type):
    /// - `.largeTitle`/`.title` — screen & sheet titles
    /// - `.title2`/`.headline` — section headers, prominent labels
    /// - `.body` — primary reading/UI text
    /// - `.subheadline` — secondary labels
    /// - `.footnote`/`.caption` — metadata, captions, status
    ///
    /// **Signature monospace = SF Mono**, used identically in the editor *and* the
    /// preview so code reads the same either way. Reach for it via
    /// `Font.system(_:design: .monospaced)` in SwiftUI, or
    /// `(NS|UI)Font.monospacedSystemFont(ofSize:weight:)` in TextKit/Highlightr —
    /// never a hardcoded face name. See DESIGN.md.
    enum Typography {
        /// Default editor/code point size (the size control adjusts around this).
        static let codeSize: CGFloat = 15
    }
}

extension DynamicTypeSize {
    /// Approximate body-text scale factor relative to the default (`.large` = 1.0).
    /// SF Mono in the editor and preview is set in raw points (TextKit/Highlightr
    /// don't pick up Dynamic Type for free), so we multiply by this to honour the
    /// user's Larger Text setting. Mirrors Apple's body ramp closely enough.
    var monoScale: CGFloat {
        switch self {
        case .xSmall: 0.82
        case .small: 0.88
        case .medium: 0.94
        case .large: 1.0
        case .xLarge: 1.12
        case .xxLarge: 1.24
        case .xxxLarge: 1.35
        case .accessibility1: 1.6
        case .accessibility2: 1.9
        case .accessibility3: 2.3
        case .accessibility4: 2.7
        case .accessibility5: 3.1
        @unknown default: 1.0
        }
    }
}
