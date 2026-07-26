import Foundation
import CoreGraphics

/// Character offsets of every `"\n"` in the document, ascending, so a line number can be
/// resolved by binary search.
///
/// The gutter needs a 1-based line number for an arbitrary character index, once per
/// *visible line fragment*, inside `draw(_:)`. That used to be
/// `nsString.substring(to: charIndex).components(separatedBy: "\n").count`, which copies
/// the entire document prefix and splits it — per visible line, per redraw. Redraws fire
/// on every scroll tick, every keystroke and every font-size change, so scrolling a large
/// file did roughly `visibleLines x documentLength` character copies per frame.
///
/// Building the offsets once per *text change* makes `draw(_:)` allocation-free and
/// O(log n) per line instead. Rebuild is O(n) and happens only when the text actually
/// changes, never on scroll — that distinction is the whole point, so keep
/// `invalidate()` off the scroll paths.
struct LineIndex {
    private var newlineOffsets: [Int] = []
    private(set) var isValid = false

    mutating func invalidate() {
        isValid = false
    }

    mutating func rebuild(from nsString: NSString) {
        var offsets: [Int] = []
        let length = nsString.length
        var searchStart = 0
        while searchStart < length {
            let found = nsString.range(
                of: "\n",
                options: [],
                range: NSRange(location: searchStart, length: length - searchStart)
            )
            guard found.location != NSNotFound else { break }
            offsets.append(found.location)
            searchStart = found.location + found.length
        }
        newlineOffsets = offsets
        isValid = true
    }

    /// 1-based number of the line containing `charIndex`: the count of newlines strictly
    /// before it, plus one. Lower-bound binary search over the ascending offsets.
    func lineNumber(at charIndex: Int) -> Int {
        var low = 0
        var high = newlineOffsets.count
        while low < high {
            let mid = low + (high - low) / 2
            if newlineOffsets[mid] < charIndex {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low + 1
    }
}

#if os(iOS)
import UIKit

/// Draws line numbers for a `UITextView`'s currently-visible glyph range. Added as a
/// subview of the text view itself (which is a `UIScrollView`) and manually kept
/// pinned to the visible top-left corner on every scroll — UITextView has no built-in
/// ruler API (unlike `NSTextView`/`NSRulerView` on macOS), so this is the standard
/// manual-gutter pattern for it.
final class LineNumberGutterView: UIView {
    weak var textView: UITextView?

    /// The *editor's* body size. The digits themselves draw at `gutterScale` of it.
    var editorFontSize: CGFloat = Theme.Typography.codeSize {
        didSet { setNeedsDisplay() }
    }

    private var glyphSize: CGFloat { editorFontSize * Theme.Typography.gutterScale }

    private var lineIndex = LineIndex()

    /// Call whenever the document text changes. Deliberately *not* called on scroll.
    func invalidateLineIndex() {
        lineIndex.invalidate()
        setNeedsDisplay()
    }

    static let width: CGFloat = 40

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let textView, let layoutManager = textView.layoutManager as NSLayoutManager?,
              let textContainer = textView.textContainer as NSTextContainer? else { return }

        let nsString = textView.text as NSString
        if !lineIndex.isValid { lineIndex.rebuild(from: nsString) }
        let visibleRect = CGRect(origin: textView.contentOffset, size: textView.bounds.size)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)

        let font = UIFont.monospacedSystemFont(ofSize: glyphSize, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.tertiaryLabel]

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { [lineIndex] fragmentRect, _, _, lineGlyphRange, _ in
            let charIndex = layoutManager.characterIndexForGlyph(at: lineGlyphRange.location)
            // Only the start of an actual "\n"-delimited line gets a number — a
            // soft-wrapped continuation of a long line doesn't (matches Xcode/TextEdit).
            let isLineStart = charIndex == 0 || nsString.character(at: charIndex - 1) == 10
            guard isLineStart else { return }
            let lineNumber = lineIndex.lineNumber(at: charIndex)
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attrs)
            let y = fragmentRect.minY - textView.contentOffset.y + textView.textContainerInset.top
            label.draw(at: CGPoint(x: Self.width - size.width - 6, y: y), withAttributes: attrs)
        }
    }
}

#elseif os(macOS)
import AppKit

/// `NSRulerView` subclass drawing line numbers for an `NSTextView`, the standard
/// mechanism macOS text editors (Xcode, TextEdit) use — driven by `NSLayoutManager`'s
/// line fragments for the currently-visible glyph range.
final class LineNumberRulerView: NSRulerView {
    weak var codeTextView: NSTextView?

    /// The *editor's* body size. Previously the macOS ruler hardcoded 11pt and had no
    /// property at all, so the A/A size control moved the code but never the gutter.
    var editorFontSize: CGFloat = Theme.Typography.codeSize {
        didSet {
            guard editorFontSize != oldValue else { return }
            ruleThickness = Self.thickness(forGlyphSize: glyphSize)
            needsDisplay = true
        }
    }

    private var glyphSize: CGFloat { editorFontSize * Theme.Typography.gutterScale }

    private var lineIndex = LineIndex()

    /// Call whenever the document text changes. Deliberately *not* called on scroll.
    func invalidateLineIndex() {
        lineIndex.invalidate()
        needsDisplay = true
    }

    /// Room for five digits plus padding. SF Mono's advance is ~0.6em; the gutter has to
    /// grow with the font or the numbers clip once the user sizes up.
    private static func thickness(forGlyphSize size: CGFloat) -> CGFloat {
        max(36, (size * 0.62 * 5).rounded(.up) + 12)
    }

    init(textView: NSTextView) {
        codeTextView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = Self.thickness(
            forGlyphSize: Theme.Typography.codeSize * Theme.Typography.gutterScale
        )
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = codeTextView, let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let nsString = textView.string as NSString
        if !lineIndex.isValid { lineIndex.rebuild(from: nsString) }
        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)

        let font = NSFont.monospacedSystemFont(ofSize: glyphSize, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.tertiaryLabelColor]

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { [lineIndex] fragmentRect, _, _, lineGlyphRange, _ in
            let charIndex = layoutManager.characterIndexForGlyph(at: lineGlyphRange.location)
            let isLineStart = charIndex == 0 || nsString.character(at: charIndex - 1) == 10
            guard isLineStart else { return }
            let lineNumber = lineIndex.lineNumber(at: charIndex)
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attrs)
            // Convert the actual document point into the ruler's coordinate space via
            // AppKit's own hierarchy-aware conversion, instead of combining a converted
            // origin with a raw fragmentRect value by hand: the two views' coordinate
            // systems aren't related by a pure translation (NSTextView is flipped; a
            // mismatched flip introduces a sign difference, not just an offset), so manual
            // arithmetic drifts further off the further a line is from the document origin
            // — which is exactly what caused this to break down at any real scroll depth.
            let documentPoint = NSPoint(x: 0, y: fragmentRect.minY + textView.textContainerInset.height)
            let rulerPoint = self.convert(documentPoint, from: textView)
            label.draw(at: NSPoint(x: self.ruleThickness - size.width - 6, y: rulerPoint.y), withAttributes: attrs)
        }
    }
}
#endif
