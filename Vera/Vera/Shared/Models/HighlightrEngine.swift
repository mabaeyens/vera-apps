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

    /// Documents above this are handed back unhighlighted.
    ///
    /// `Highlightr.highlight` passes the whole document to JavaScriptCore in one call with
    /// no chunking and no incremental range, and it contains no suspension point, so a
    /// long pass cannot be cancelled once started — the `Task.isCancelled` checks here can
    /// only skip a call that hasn't begun. A cap is therefore the only real protection: a
    /// huge file that opens instantly in plain monospace beats one that wedges the app.
    nonisolated static let maxHighlightBytes = 1_000_000

    private var highlightr: Highlightr?
    private var currentTheme: String?

    /// Highlight and split into per-line `AttributedString`s, both inside the actor.
    ///
    /// The split walks the whole highlighted string character by character and allocates
    /// one `AttributedString` per line. Callers used to do it after `await`ing
    /// `highlight`, which resumes on the MainActor — so the highlighting was correctly off
    /// main while the equally O(n) post-processing landed straight back on it. Doing both
    /// here keeps the main thread out of it entirely.
    func highlightLines(code: String, language: String, theme: String, fontSize: CGFloat) -> [AttributedString]? {
        guard let attr = highlight(code: code, language: language, theme: theme, fontSize: fontSize) else {
            return nil
        }
        guard !Task.isCancelled else { return nil }
        return Self.splitLines(of: attr)
    }

    /// Split a highlighted `AttributedString` on "\n" boundaries into per-line
    /// `AttributedString`s, preserving each character's attributes.
    private static func splitLines(of attr: AttributedString) -> [AttributedString] {
        var lines: [AttributedString] = []
        var start = attr.startIndex
        var idx = attr.startIndex
        while idx < attr.endIndex {
            if attr.characters[idx] == "\n" {
                lines.append(AttributedString(attr[start..<idx]))
                start = attr.index(afterCharacter: idx)
            }
            idx = attr.index(afterCharacter: idx)
        }
        lines.append(AttributedString(attr[start..<attr.endIndex]))
        return lines
    }

    func highlight(code: String, language: String, theme: String, fontSize: CGFloat) -> AttributedString? {
        // Bails out calls that got queued on the actor behind a slower one and whose
        // originating `.task(id:)` has since been cancelled (e.g. superseded by a rapid
        // follow-up font-size change) — skips the full highlight pass and its
        // full-file `AttributedString` allocation instead of doing wasted, ever-piling-up
        // work. See IPAD_FONT_SIZE_HANG.md, remediation (b).
        guard !Task.isCancelled else { return nil }
        guard code.utf8.count <= Self.maxHighlightBytes else { return nil }
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
