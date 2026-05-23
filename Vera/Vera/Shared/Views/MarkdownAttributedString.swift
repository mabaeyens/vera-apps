import Foundation
import Highlightr
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Entry point

func makeMarkdownAttributedString(
    _ markdown: String,
    fontSize: CGFloat,
    isDarkMode: Bool
) -> NSAttributedString {
    MarkdownRenderer(fontSize: fontSize, isDarkMode: isDarkMode).render(markdown)
}

// MARK: - Inline patterns (compiled once)

private struct InlineMatch {
    let range: Range<String.Index>
    let kind: Kind
    let content: String
    let url: String?

    enum Kind { case boldItalic, bold, italic, strikethrough, code, link }
}

private let inlinePatterns: [(regex: NSRegularExpression, kind: InlineMatch.Kind)] = {
    let specs: [(String, InlineMatch.Kind)] = [
        (#"\*\*\*((?:[^*]|\*(?!\*\*))+?)\*\*\*"#, .boldItalic),
        (#"\*\*((?:[^*]|\*(?!\*))+?)\*\*"#,        .bold),
        (#"\*([^*\n]+?)\*"#,                        .italic),
        (#"_([^_\n]+?)_"#,                          .italic),
        (#"~~([^~\n]+?)~~"#,                        .strikethrough),
        (#"`([^`\n]+)`"#,                           .code),
        (#"\[([^\]\n]+)\]\(([^)\n]+)\)"#,           .link),
    ]
    return specs.compactMap { pattern, kind in
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        return (re, kind)
    }
}()

// MARK: - HR Attachment

#if os(iOS)
private final class HRAttachment: NSTextAttachment {
    private let color: UIColor
    init(color: UIColor) { self.color = color; super.init(data: nil, ofType: nil) }
    required init?(coder: NSCoder) { nil }
    override func attachmentBounds(for textContainer: NSTextContainer?,
                                   proposedLineFragment lineFrag: CGRect,
                                   glyphPosition: CGPoint,
                                   characterIndex: Int) -> CGRect {
        let pad = textContainer?.lineFragmentPadding ?? 0
        let w   = (textContainer?.size.width ?? lineFrag.width) - pad * 2
        return CGRect(x: 0, y: -1, width: max(w, 0), height: 1)
    }
    override func image(forBounds imageBounds: CGRect,
                        textContainer: NSTextContainer?,
                        characterIndex: Int) -> UIImage? {
        UIGraphicsImageRenderer(bounds: imageBounds).image { _ in
            color.setFill()
            UIRectFill(imageBounds)
        }
    }
}
#elseif os(macOS)
private final class HRAttachment: NSTextAttachment {
    private let color: NSColor
    init(color: NSColor) { self.color = color; super.init(data: nil, ofType: nil) }
    required init?(coder: NSCoder) { nil }
    override func attachmentBounds(for textContainer: NSTextContainer?,
                                   proposedLineFragment lineFrag: CGRect,
                                   glyphPosition: CGPoint,
                                   characterIndex: Int) -> CGRect {
        let pad = textContainer?.lineFragmentPadding ?? 0
        let w   = (textContainer?.size.width ?? lineFrag.width) - pad * 2
        return CGRect(x: 0, y: -1, width: max(w, 0), height: 1)
    }
    override func image(forBounds imageBounds: CGRect,
                        textContainer: NSTextContainer?,
                        characterIndex: Int) -> NSImage? {
        let img = NSImage(size: imageBounds.size)
        img.lockFocus()
        color.setFill()
        imageBounds.fill()
        img.unlockFocus()
        return img
    }
}
#endif

// MARK: - Renderer

private struct MarkdownRenderer {
    let fontSize: CGFloat
    let isDarkMode: Bool

    // MARK: Colors
    #if os(iOS)
    var textColor:        UIColor { .label }
    var secondaryColor:   UIColor { .secondaryLabel }
    var codeBackground:   UIColor { isDarkMode ? UIColor(white: 0.15, alpha: 1) : UIColor(white: 0.95, alpha: 1) }
    var blockquoteColor:  UIColor { .tertiaryLabel }
    var linkColor:        UIColor { .link }
    var separatorColor:   UIColor { .separator }
    #else
    var textColor:        NSColor { .labelColor }
    var secondaryColor:   NSColor { .secondaryLabelColor }
    var codeBackground:   NSColor { isDarkMode ? NSColor(white: 0.15, alpha: 1) : NSColor(white: 0.95, alpha: 1) }
    var blockquoteColor:  NSColor { .tertiaryLabelColor }
    var linkColor:        NSColor { .linkColor }
    var separatorColor:   NSColor { .separatorColor }
    #endif

    // MARK: Fonts
    #if os(iOS)
    func bodyFont(bold: Bool = false, italic: Bool = false) -> UIFont {
        let base = UIFont.systemFont(ofSize: fontSize)
        var traits: UIFontDescriptor.SymbolicTraits = []
        if bold   { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        guard !traits.isEmpty,
              let desc = base.fontDescriptor.withSymbolicTraits(traits) else { return base }
        return UIFont(descriptor: desc, size: fontSize)
    }

    func headingFont(level: Int) -> UIFont {
        let scale: CGFloat = [1: 2.0, 2: 1.5, 3: 1.25, 4: 1.1][level] ?? 1.0
        let size = fontSize * scale
        let base = UIFont.systemFont(ofSize: size, weight: .bold)
        return base
    }

    var monoFont:      UIFont { .monospacedSystemFont(ofSize: fontSize * 0.9,  weight: .regular) }
    var monoBlockFont: UIFont { .monospacedSystemFont(ofSize: fontSize * 0.85, weight: .regular) }
    #else
    func bodyFont(bold: Bool = false, italic: Bool = false) -> NSFont {
        let base = NSFont.systemFont(ofSize: fontSize)
        var traits: NSFontDescriptor.SymbolicTraits = []
        if bold   { traits.insert(.bold) }
        if italic { traits.insert(.italic) }
        guard !traits.isEmpty else { return base }
        let desc = base.fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: desc, size: fontSize) ?? base
    }

    func headingFont(level: Int) -> NSFont {
        let scale: CGFloat = [1: 2.0, 2: 1.5, 3: 1.25, 4: 1.1][level] ?? 1.0
        let size = fontSize * scale
        return NSFont.systemFont(ofSize: size, weight: .bold)
    }

    var monoFont:      NSFont { .monospacedSystemFont(ofSize: fontSize * 0.9,  weight: .regular) }
    var monoBlockFont: NSFont { .monospacedSystemFont(ofSize: fontSize * 0.85, weight: .regular) }
    #endif

    // MARK: - Paragraph style helpers

    func bodyParagraphStyle() -> NSMutableParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.paragraphSpacing = fontSize * 0.4
        return p
    }

    // MARK: - Render

    func render(_ markdown: String) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        var i = 0
        var needsLeadingNewline = false

        func append(_ block: NSAttributedString) {
            if needsLeadingNewline {
                out.append(NSAttributedString(string: "\n", attributes: baseAttrs()))
            }
            out.append(block)
            needsLeadingNewline = true
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Empty line — blank paragraph break
            if trimmed.isEmpty {
                if needsLeadingNewline {
                    out.append(NSAttributedString(string: "\n", attributes: baseAttrs()))
                }
                i += 1
                continue
            }

            // Code fence
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                let fence = line.hasPrefix("```") ? "```" : "~~~"
                let lang = line.dropFirst(fence.count).trimmingCharacters(in: .whitespaces)
                i += 1
                var codeLines: [String] = []
                while i < lines.count && !lines[i].hasPrefix(fence) {
                    codeLines.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 }  // closing fence
                append(renderCodeBlock(codeLines, language: lang.isEmpty ? nil : lang))
                continue
            }

            // Heading
            if line.hasPrefix("#") {
                let level = min(line.prefix(while: { $0 == "#" }).count, 6)
                let rest = line.dropFirst(level)
                if rest.hasPrefix(" ") {
                    append(renderHeading(String(rest.dropFirst()), level: level))
                    i += 1
                    continue
                }
            }

            // Horizontal rule
            if trimmed.count >= 3 &&
               (trimmed.allSatisfy({ $0 == "-" }) ||
                trimmed.allSatisfy({ $0 == "*" }) ||
                trimmed.allSatisfy({ $0 == "_" })) {
                append(renderHR())
                i += 1
                continue
            }

            // Blockquote
            if line.hasPrefix("> ") || line == ">" {
                var bqLines: [String] = []
                while i < lines.count {
                    if lines[i].hasPrefix("> ") {
                        bqLines.append(String(lines[i].dropFirst(2)))
                        i += 1
                    } else if lines[i] == ">" {
                        bqLines.append("")
                        i += 1
                    } else { break }
                }
                append(renderBlockquote(bqLines.joined(separator: "\n")))
                continue
            }

            // Bullet list
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                var items: [String] = []
                while i < lines.count {
                    let l = lines[i]
                    if l.hasPrefix("- ") || l.hasPrefix("* ") || l.hasPrefix("+ ") {
                        items.append(String(l.dropFirst(2)))
                        i += 1
                    } else { break }
                }
                append(renderBulletList(items))
                continue
            }

            // Ordered list
            if line.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                var items: [String] = []
                var start = 1
                var isFirst = true
                while i < lines.count {
                    let l = lines[i]
                    guard let numRange = l.range(of: #"^\d+\. "#, options: .regularExpression) else { break }
                    if isFirst {
                        start = Int(String(l[numRange].dropLast(2))) ?? 1
                        isFirst = false
                    }
                    items.append(String(l[numRange.upperBound...]))
                    i += 1
                }
                append(renderOrderedList(items, start: start))
                continue
            }

            // Table
            if line.hasPrefix("|") {
                var rows: [String] = []
                while i < lines.count && lines[i].hasPrefix("|") {
                    rows.append(lines[i])
                    i += 1
                }
                append(renderTable(rows))
                continue
            }

            // Paragraph — collect soft-wrapped lines
            var paraLines: [String] = []
            while i < lines.count {
                let l = lines[i]
                let t = l.trimmingCharacters(in: .whitespaces)
                if t.isEmpty { break }
                if l.hasPrefix("#") || l.hasPrefix("> ") || l == ">" ||
                   l.hasPrefix("```") || l.hasPrefix("~~~") ||
                   l.hasPrefix("- ") || l.hasPrefix("* ") || l.hasPrefix("+ ") ||
                   l.hasPrefix("|") { break }
                if l.range(of: #"^\d+\. "#, options: .regularExpression) != nil { break }
                let tr = l.trimmingCharacters(in: .whitespaces)
                if tr.count >= 3 && (tr.allSatisfy({ $0 == "-" }) ||
                                     tr.allSatisfy({ $0 == "*" }) ||
                                     tr.allSatisfy({ $0 == "_" })) { break }
                paraLines.append(l)
                i += 1
            }
            if !paraLines.isEmpty {
                append(renderParagraph(paraLines.joined(separator: " ")))
            }
        }

        return out
    }

    // MARK: - Block renderers

    private func baseAttrs() -> [NSAttributedString.Key: Any] {
        [.font: bodyFont(), .foregroundColor: textColor]
    }

    private func renderHeading(_ text: String, level: Int) -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.paragraphSpacing      = fontSize * 0.25
        p.paragraphSpacingBefore = level == 1 ? fontSize * 0.4 : fontSize * 0.2
        return NSAttributedString(string: text, attributes: [
            .font: headingFont(level: level),
            .foregroundColor: textColor,
            .paragraphStyle: p,
        ])
    }

    private func renderParagraph(_ text: String) -> NSAttributedString {
        applyInline(text, base: [
            .font: bodyFont(),
            .foregroundColor: textColor,
            .paragraphStyle: bodyParagraphStyle(),
        ])
    }

    private func renderCodeBlock(_ codeLines: [String], language: String?) -> NSAttributedString {
        let code = codeLines.joined(separator: "\n")
        let p = NSMutableParagraphStyle()
        p.paragraphSpacing = fontSize * 0.1

        if let lang = language,
           let hl = Highlightr() {
            hl.setTheme(to: isDarkMode ? "atom-one-dark" : "atom-one-light")
            if let highlighted = hl.highlight(code, as: lang, fastRender: true) {
                let wrapped = NSMutableAttributedString(attributedString: highlighted)
                let fullRange = NSRange(location: 0, length: wrapped.length)
                wrapped.addAttributes([
                    .font: monoBlockFont,
                    .backgroundColor: codeBackground,
                    .paragraphStyle: p,
                ], range: fullRange)
                return wrapped
            }
        }

        return NSAttributedString(string: code, attributes: [
            .font: monoBlockFont,
            .foregroundColor: textColor,
            .backgroundColor: codeBackground,
            .paragraphStyle: p,
        ])
    }

    private func renderBlockquote(_ text: String) -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.firstLineHeadIndent = fontSize
        p.headIndent          = fontSize
        p.paragraphSpacing    = fontSize * 0.2
        return applyInline(text, base: [
            .font: bodyFont(italic: true),
            .foregroundColor: blockquoteColor,
            .paragraphStyle: p,
        ])
    }

    private func renderBulletList(_ items: [String]) -> NSAttributedString {
        let out = NSMutableAttributedString()
        for (idx, itemText) in items.enumerated() {
            let p = NSMutableParagraphStyle()
            let indent = fontSize * 1.5
            p.firstLineHeadIndent = 0
            p.headIndent          = indent
            p.tabStops            = [NSTextTab(textAlignment: .left, location: indent)]
            p.paragraphSpacing    = fontSize * 0.15
            let attrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont(), .foregroundColor: textColor, .paragraphStyle: p,
            ]
            let row = NSMutableAttributedString(string: "•\t", attributes: attrs)
            row.append(applyInline(itemText, base: attrs))
            if idx < items.count - 1 {
                row.append(NSAttributedString(string: "\n", attributes: attrs))
            }
            out.append(row)
        }
        return out
    }

    private func renderOrderedList(_ items: [String], start: Int) -> NSAttributedString {
        let out = NSMutableAttributedString()
        for (idx, itemText) in items.enumerated() {
            let number = start + idx
            let p = NSMutableParagraphStyle()
            let indent = fontSize * 2.0
            p.firstLineHeadIndent = 0
            p.headIndent          = indent
            p.tabStops            = [NSTextTab(textAlignment: .left, location: indent)]
            p.paragraphSpacing    = fontSize * 0.15
            let attrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont(), .foregroundColor: textColor, .paragraphStyle: p,
            ]
            let row = NSMutableAttributedString(string: "\(number).\t", attributes: attrs)
            row.append(applyInline(itemText, base: attrs))
            if idx < items.count - 1 {
                row.append(NSAttributedString(string: "\n", attributes: attrs))
            }
            out.append(row)
        }
        return out
    }

    private func renderTable(_ rows: [String]) -> NSAttributedString {
        let out = NSMutableAttributedString()
        // Filter pure-separator rows (e.g. |---|:---:|)
        let dataRows = rows.filter { row in
            let stripped = row
                .replacingOccurrences(of: "|", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: " ", with: "")
            return !stripped.isEmpty
        }
        // Collect all cells to compute column widths
        let parsed: [[String]] = dataRows.map { row in
            row.components(separatedBy: "|")
               .map { $0.trimmingCharacters(in: .whitespaces) }
               .filter { !$0.isEmpty }
        }
        let colCount = parsed.map(\.count).max() ?? 0
        var colWidths = [Int](repeating: 0, count: colCount)
        for cells in parsed {
            for (ci, cell) in cells.enumerated() where ci < colCount {
                colWidths[ci] = max(colWidths[ci], cell.count)
            }
        }
        let p = NSMutableParagraphStyle()
        p.paragraphSpacing = fontSize * 0.15
        for (rowIdx, cells) in parsed.enumerated() {
            let isHeader = rowIdx == 0
            var line = ""
            for ci in 0..<colCount {
                let cell = ci < cells.count ? cells[ci] : ""
                let pad = String(repeating: " ", count: colWidths[ci] - cell.count)
                line += " \(cell)\(pad) │"
            }
            if line.hasSuffix(" │") { line = String(line.dropLast(2)) }
            if rowIdx < dataRows.count - 1 { line += "\n" }
            var rowAttrs: [NSAttributedString.Key: Any] = [
                .font: isHeader ? bodyFont(bold: true) : monoBlockFont,
                .foregroundColor: textColor,
                .paragraphStyle: p,
            ]
            if isHeader { rowAttrs[.backgroundColor] = codeBackground }
            out.append(NSAttributedString(string: line, attributes: rowAttrs))
        }
        return out
    }

    private func renderHR() -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.paragraphSpacing       = fontSize * 0.4
        p.paragraphSpacingBefore = fontSize * 0.4
        let attachment = HRAttachment(color: separatorColor)
        let str = NSMutableAttributedString(attachment: attachment)
        str.addAttribute(.paragraphStyle, value: p, range: NSRange(location: 0, length: str.length))
        return str
    }

    // MARK: - Inline formatting

    private func applyInline(
        _ text: String,
        base: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        guard text.contains(where: { "*_`~[".contains($0) }) else {
            return NSAttributedString(string: text, attributes: base)
        }

        // Collect non-overlapping matches across all patterns (priority order)
        var matches: [InlineMatch] = []
        var usedRanges: [Range<String.Index>] = []

        for (regex, kind) in inlinePatterns {
            let nsRange = NSRange(text.startIndex..., in: text)
            for result in regex.matches(in: text, range: nsRange) {
                guard let range = Range(result.range, in: text) else { continue }
                if usedRanges.contains(where: { $0.overlaps(range) }) { continue }

                let content: String
                let url: String?
                if kind == .link, result.numberOfRanges >= 3,
                   let textRange = Range(result.range(at: 1), in: text),
                   let urlRange  = Range(result.range(at: 2), in: text) {
                    content = String(text[textRange])
                    url     = String(text[urlRange])
                } else if result.numberOfRanges >= 2,
                          let groupRange = Range(result.range(at: 1), in: text) {
                    content = String(text[groupRange])
                    url     = nil
                } else {
                    content = String(text[range])
                    url     = nil
                }

                matches.append(InlineMatch(range: range, kind: kind, content: content, url: url))
                usedRanges.append(range)
            }
        }

        guard !matches.isEmpty else {
            return NSAttributedString(string: text, attributes: base)
        }

        matches.sort { $0.range.lowerBound < $1.range.lowerBound }

        let out = NSMutableAttributedString()
        var cursor = text.startIndex

        for match in matches {
            if cursor < match.range.lowerBound {
                out.append(NSAttributedString(string: String(text[cursor..<match.range.lowerBound]), attributes: base))
            }
            out.append(styledSpan(match, base: base))
            cursor = match.range.upperBound
        }
        if cursor < text.endIndex {
            out.append(NSAttributedString(string: String(text[cursor...]), attributes: base))
        }
        return out
    }

    private func styledSpan(_ match: InlineMatch, base: [NSAttributedString.Key: Any]) -> NSAttributedString {
        var attrs = base
        switch match.kind {
        case .boldItalic:
            attrs[.font] = bodyFont(bold: true, italic: true)
        case .bold:
            attrs[.font] = bodyFont(bold: true)
        case .italic:
            attrs[.font] = bodyFont(italic: true)
        case .strikethrough:
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attrs[.strikethroughColor] = textColor
        case .code:
            attrs[.font]            = monoFont
            attrs[.backgroundColor] = codeBackground
        case .link:
            if let urlStr = match.url, let url = URL(string: urlStr) {
                attrs[.link]            = url
                attrs[.foregroundColor] = linkColor
            }
        }
        return NSAttributedString(string: match.content, attributes: attrs)
    }
}
