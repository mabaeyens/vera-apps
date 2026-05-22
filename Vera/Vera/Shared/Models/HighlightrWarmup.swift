import Highlightr

// Forces Highlightr's SPM bundle to load on the main thread before any editor
// view is constructed. Without this, a cold launch triggered by an external app
// (e.g. Claude Desktop "Open in Vera") can arrive while the bundle is uninitialized,
// causing CodeAttributedString's internal Highlightr()! to crash with a nil unwrap.
enum HighlightrWarmup {
    static func prime() {
        _ = Highlightr()
    }
}
