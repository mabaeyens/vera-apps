import Foundation
import CoreGraphics

// Phase 2 v1: proportional approximation.
// Maps a tap's Y position in the rendered view to a character offset in the raw string.
// Good enough for most cases; upgrade to TextKit 2 exact mapping if users report it as jarring.
enum SmartAnchorResolver {
    static func characterOffset(tapY: CGFloat, viewHeight: CGFloat, text: String) -> String.Index {
        guard viewHeight > 0, !text.isEmpty else { return text.startIndex }
        let ratio = max(0, min(1, tapY / viewHeight))
        let offset = Int(Double(text.count) * Double(ratio))
        return text.index(text.startIndex, offsetBy: min(offset, text.count - 1))
    }
}
