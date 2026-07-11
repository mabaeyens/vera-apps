import Highlightr

#if os(iOS)
import UIKit
private typealias PlatformFont = UIFont
#else
import AppKit
private typealias PlatformFont = NSFont
#endif

/// Configure a Highlightr instance to use SF Mono for regular **and** bold/italic.
///
/// Highlightr's `Theme.setCodeFont` derives bold/italic by building a font descriptor
/// from `font.familyName` + face "Bold"/"Italic". The system monospaced font's family
/// (`.AppleSystemUIFontMonospaced`) has no resolvable named face that way, so it falls
/// back to the **proportional** system font — which is why headings/bold tokens render
/// in a different typeface than the monospaced body. We override the derived fonts with
/// real monospaced variants so the whole editor stays one face.
/// `nonisolated`: called from `HighlightrEngine`, a plain (non-MainActor) actor, so this
/// can't be implicitly MainActor-isolated (the project's default). Font-creation APIs
/// here (UIFont/NSFont) are thread-safe, so this is safe to run off the main actor.
nonisolated func applyMonoFont(to highlightr: Highlightr, size: CGFloat) {
    guard let theme = highlightr.theme else { return }
    let regular = PlatformFont.monospacedSystemFont(ofSize: size, weight: .regular)
    theme.setCodeFont(regular)
    theme.boldCodeFont = PlatformFont.monospacedSystemFont(ofSize: size, weight: .bold)
    theme.italicCodeFont = italicMonospacedFont(size: size) ?? regular
}

/// SF Mono with the italic trait applied while preserving the monospace trait.
private nonisolated func italicMonospacedFont(size: CGFloat) -> PlatformFont? {
    let base = PlatformFont.monospacedSystemFont(ofSize: size, weight: .regular)
    #if os(iOS)
    guard let descriptor = base.fontDescriptor.withSymbolicTraits([.traitItalic, .traitMonoSpace]) else {
        return nil
    }
    return UIFont(descriptor: descriptor, size: size)
    #else
    let descriptor = base.fontDescriptor.withSymbolicTraits([.italic, .monoSpace])
    return NSFont(descriptor: descriptor, size: size)
    #endif
}
