import Foundation

#if os(iOS)
import UIKit

/// Draws line numbers for a `UITextView`'s currently-visible glyph range. Added as a
/// subview of the text view itself (which is a `UIScrollView`) and manually kept
/// pinned to the visible top-left corner on every scroll — UITextView has no built-in
/// ruler API (unlike `NSTextView`/`NSRulerView` on macOS), so this is the standard
/// manual-gutter pattern for it.
final class LineNumberGutterView: UIView {
    weak var textView: UITextView?
    var fontSize: CGFloat = 13 {
        didSet { setNeedsDisplay() }
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
        let visibleRect = CGRect(origin: textView.contentOffset, size: textView.bounds.size)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)

        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.tertiaryLabel]

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { fragmentRect, _, _, lineGlyphRange, _ in
            let charIndex = layoutManager.characterIndexForGlyph(at: lineGlyphRange.location)
            // Only the start of an actual "\n"-delimited line gets a number — a
            // soft-wrapped continuation of a long line doesn't (matches Xcode/TextEdit).
            let isLineStart = charIndex == 0 || nsString.character(at: charIndex - 1) == 10
            guard isLineStart else { return }
            let lineNumber = nsString.substring(to: charIndex).components(separatedBy: "\n").count
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

    init(textView: NSTextView) {
        codeTextView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 36
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = codeTextView, let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let nsString = textView.string as NSString
        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)

        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.tertiaryLabelColor]

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { fragmentRect, _, _, lineGlyphRange, _ in
            let charIndex = layoutManager.characterIndexForGlyph(at: lineGlyphRange.location)
            let isLineStart = charIndex == 0 || nsString.character(at: charIndex - 1) == 10
            guard isLineStart else { return }
            let lineNumber = nsString.substring(to: charIndex).components(separatedBy: "\n").count
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attrs)
            // NSTextView's line-fragment y-origin is already in the view's own flipped
            // coordinate space, which the ruler shares along its scrolled axis.
            let y = fragmentRect.minY + textView.textContainerInset.height - self.convert(NSPoint.zero, from: textView).y
            label.draw(at: NSPoint(x: self.ruleThickness - size.width - 6, y: y), withAttributes: attrs)
        }
    }
}
#endif
