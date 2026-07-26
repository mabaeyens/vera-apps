import SwiftUI
#if os(iOS)
import UIKit
#endif

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
        /// `Defaults.FontSize.default` must agree with this; see DESIGN.md.
        static let codeSize: CGFloat = 15

        /// Line-number gutter size, relative to the editor's body size. The gutter is
        /// reference furniture, not content, so it reads one step quieter than the code
        /// it numbers (the convention in Xcode and TextEdit).
        static let gutterScale: CGFloat = 0.85

        /// What a piece of text *is*, so its size comes from one table instead of a
        /// literal at the call site. Everything reads at the user's chosen size (hence
        /// 1.0) except the gutter — "15 everywhere" is the point.
        enum Role {
            case body, code, table, gutter

            var multiplier: CGFloat {
                switch self {
                case .body, .code, .table: 1.0
                case .gutter: gutterScale
                }
            }
        }

        /// Size **before** Dynamic Type. Hand this to MarkdownUI, which applies Apple's
        /// `.body` ramp itself via `ScaledMetric` — passing it an already-scaled value
        /// would scale twice.
        static func unscaledSize(_ role: Role, preference: CGFloat) -> CGFloat {
            preference * role.multiplier
        }

        /// Fully resolved size, Dynamic Type included. Use for TextKit/Highlightr and any
        /// raw `.font(.system(size:))`, none of which scale for free.
        static func size(_ role: Role, preference: CGFloat, typeSize: DynamicTypeSize) -> CGFloat {
            scaled(unscaledSize(role, preference: preference), for: typeSize)
        }

        /// Apple's `.body` Dynamic Type ramp.
        ///
        /// Vera used to carry a hand-written `monoScale` table here, which its own comment
        /// admitted only "mirrors Apple's body ramp closely enough". That left three
        /// different ramps running at once: `monoScale` in the editor and code blocks,
        /// Apple's real ramp inside MarkdownUI, and none at all in tables. At
        /// `.accessibility5` the editor reached ~55.8pt while table cells stayed at 14.4pt.
        /// Using the real metrics means every surface agrees with MarkdownUI by
        /// construction rather than by approximation.
        static func scaled(_ size: CGFloat, for typeSize: DynamicTypeSize) -> CGFloat {
            #if os(iOS)
            UIFontMetrics(forTextStyle: .body).scaledValue(
                for: size,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: typeSize.contentSizeCategory)
            )
            #else
            // macOS has no Dynamic Type; the size control is the lever there.
            size
            #endif
        }
    }
}

#if os(iOS)
extension DynamicTypeSize {
    /// Bridge to UIKit so `UIFontMetrics` can be asked for the *exact* scaled value for
    /// the SwiftUI environment's size, rather than whatever the ambient trait collection
    /// happens to be (they differ wherever `.dynamicTypeSize(...)` is applied).
    var contentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}
#endif
