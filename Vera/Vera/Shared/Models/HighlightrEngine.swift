import Foundation
import Highlightr
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Runs Highlightr (JavaScriptCore-backed) syntax highlighting off the main actor, on a
/// single shared, lazily-created instance. `Highlightr()` init is expensive (spins up a
/// fresh JSContext and loads highlight.js + every grammar/theme) — reusing one instance
/// instead of constructing a new one per code view avoids paying that cost on every file
/// open, and the actor serializes access so reconfiguring the shared instance's
/// theme/font per call is safe even if multiple views highlight concurrently.
actor HighlightrEngine {
    static let shared = HighlightrEngine()

    private var highlightr: Highlightr?
    private var currentTheme: String?

    func highlight(code: String, language: String, theme: String, fontSize: CGFloat) -> AttributedString? {
        // Bails out calls that got queued on the actor behind a slower one and whose
        // originating `.task(id:)` has since been cancelled (e.g. superseded by a rapid
        // follow-up font-size change) — skips the full highlight pass and its
        // full-file `AttributedString` allocation instead of doing wasted, ever-piling-up
        // work. See IPAD_FONT_SIZE_HANG.md, remediation (b).
        guard !Task.isCancelled else { return nil }
        let h: Highlightr
        if let existing = highlightr {
            h = existing
        } else {
            guard let created = Highlightr() else { return nil }
            highlightr = created
            h = created
        }
        if currentTheme != theme {
            h.setTheme(to: theme)
            currentTheme = theme
        }
        // SF Mono — the same signature monospace the editor uses (see DESIGN.md),
        // including correct bold/italic variants, so a code block reads identically
        // whether you're editing or previewing. Re-applied every call since fontSize
        // (Dynamic Type) can differ between callers of the shared instance.
        applyMonoFont(to: h, size: fontSize)
        guard let ns = h.highlight(code, as: language) else { return nil }
        let mutable = NSMutableAttributedString(attributedString: ns)
        mutable.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: mutable.length))
        #if os(macOS)
        return try? AttributedString(mutable, including: \.appKit)
        #else
        return try? AttributedString(mutable, including: \.uiKit)
        #endif
    }
}
