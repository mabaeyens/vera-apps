import Foundation

/// Markdown list and blockquote editing: what Return and Tab do on a list line.
///
/// Pure string logic with no UIKit/AppKit, shared by both editors so the behavior can't
/// drift between platforms. All offsets are UTF-16, because that is what `NSRange` and
/// the text views use.
enum ListContinuation {
    /// A replacement to apply to the text, and where to put the selection afterwards.
    struct Edit {
        let range: NSRange
        let replacement: String
        let selection: NSRange
    }

    // MARK: - Line parsing

    private struct Marker {
        let indent: String
        let quote: String
        /// "-", "*", "+" or a number with its delimiter ("3.", "3)"). nil for a bare quote.
        let bullet: String?
        let isTask: Bool
        /// UTF-16 length of everything before the item's text.
        let prefixLength: Int
        let content: String
    }

    private static func parse(_ line: String) -> Marker? {
        var rest = Substring(line)
        let indent = String(rest.prefix { $0 == " " || $0 == "\t" })
        rest = rest.dropFirst(indent.count)

        var quote = ""
        while rest.first == ">" {
            quote.append(">")
            rest = rest.dropFirst()
            if rest.first == " " {
                quote.append(" ")
                rest = rest.dropFirst()
            }
        }

        var bullet: String?
        if let c = rest.first, "-*+".contains(c), rest.dropFirst().first == " " {
            bullet = String(c)
            rest = rest.dropFirst()
        } else {
            let digits = rest.prefix { $0.isASCII && $0.isNumber }
            if !digits.isEmpty, digits.count <= 9,
               let delimiter = rest.dropFirst(digits.count).first, delimiter == "." || delimiter == ")",
               rest.dropFirst(digits.count + 1).first == " " {
                bullet = String(digits) + String(delimiter)
                rest = rest.dropFirst(digits.count + 1)
            }
        }

        var isTask = false
        if bullet != nil {
            rest = rest.drop { $0 == " " }
            let head = rest.prefix(3)
            if head == "[ ]" || head == "[x]" || head == "[X]",
               rest.count == 3 || rest.dropFirst(3).first == " " {
                isTask = true
                rest = rest.dropFirst(3).drop { $0 == " " }
            }
        }

        guard bullet != nil || !quote.isEmpty else { return nil }
        let prefix = String(line.dropLast(rest.count))
        return Marker(
            indent: indent, quote: quote, bullet: bullet, isTask: isTask,
            prefixLength: prefix.utf16.count, content: String(rest)
        )
    }

    /// The bullet to use on the line after `bullet`: same symbol, or the next number.
    private static func nextBullet(after bullet: String) -> String {
        guard let delimiter = bullet.last, delimiter == "." || delimiter == ")",
              let number = Int(bullet.dropLast()) else { return bullet }
        return "\(number + 1)\(delimiter)"
    }

    /// True when `location` sits inside an unclosed ``` or ~~~ fence.
    private static func isInsideFence(_ text: NSString, before location: Int) -> Bool {
        guard location > 0 else { return false }
        var open = false
        text.enumerateSubstrings(
            in: NSRange(location: 0, length: location), options: .byLines
        ) { line, _, _, _ in
            guard let trimmed = line?.drop(while: { $0 == " " || $0 == "\t" }) else { return }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { open.toggle() }
        }
        return open
    }

    private static func contentRange(ofLineAt location: Int, in text: NSString) -> (line: NSRange, content: NSRange) {
        let line = text.lineRange(for: NSRange(location: location, length: 0))
        var content = line
        while content.length > 0 {
            let last = text.character(at: content.location + content.length - 1)
            guard last == 10 || last == 13 else { break }
            content.length -= 1
        }
        return (line, content)
    }

    // MARK: - Return

    /// What Return should do at `selection`, or nil to leave the text view's default
    /// (a plain newline) alone.
    static func returnEdit(in text: String, selection: NSRange) -> Edit? {
        let ns = text as NSString
        guard selection.location <= ns.length, NSMaxRange(selection) <= ns.length else { return nil }

        let (_, content) = contentRange(ofLineAt: selection.location, in: ns)
        // A selection spanning lines is replaced by the default behavior.
        guard NSMaxRange(selection) <= NSMaxRange(content) else { return nil }
        guard let marker = parse(ns.substring(with: content)) else { return nil }

        let caret = selection.location - content.location
        // Return inside the marker itself ("- " or "1. ") is just a newline.
        guard caret >= marker.prefixLength else { return nil }
        guard !isInsideFence(ns, before: content.location) else { return nil }

        let isEmptyItem = marker.content.trimmingCharacters(in: .whitespaces).isEmpty
        if isEmptyItem && selection.length == 0 && caret == content.length {
            // Return on an empty item ends the list. A nested item steps out one level first.
            if !marker.indent.isEmpty {
                let line = ns.substring(with: content)
                let outdented = removingLeadingIndent(from: line)
                let newCaret = content.location + outdented.utf16.count
                return Edit(range: content, replacement: outdented, selection: NSRange(location: newCaret, length: 0))
            }
            return Edit(range: content, replacement: "", selection: NSRange(location: content.location, length: 0))
        }

        var prefix = "\n" + marker.indent + marker.quote
        if let bullet = marker.bullet {
            prefix += nextBullet(after: bullet) + " " + (marker.isTask ? "[ ] " : "")
        }
        return Edit(
            range: selection, replacement: prefix,
            selection: NSRange(location: selection.location + prefix.utf16.count, length: 0)
        )
    }

    // MARK: - Tab

    private static func removingLeadingIndent(from line: String) -> String {
        if line.hasPrefix("\t") { return String(line.dropFirst()) }
        if line.hasPrefix("  ") { return String(line.dropFirst(2)) }
        if line.hasPrefix(" ") { return String(line.dropFirst()) }
        return line
    }

    /// Indent (or outdent) the list lines under `selection`. nil when the first selected
    /// line isn't a list item or quote, so Tab behaves as before everywhere else.
    static func indentEdit(in text: String, selection: NSRange, outdent: Bool) -> Edit? {
        let ns = text as NSString
        guard selection.location <= ns.length, NSMaxRange(selection) <= ns.length else { return nil }

        let (_, firstContent) = contentRange(ofLineAt: selection.location, in: ns)
        guard parse(ns.substring(with: firstContent)) != nil else { return nil }
        guard !isInsideFence(ns, before: firstContent.location) else { return nil }

        let block = ns.lineRange(for: selection)
        let original = ns.substring(with: block)
        var lines = original.components(separatedBy: "\n")
        var firstDelta = 0
        var totalDelta = 0
        for index in lines.indices {
            let line = lines[index]
            guard !line.isEmpty else { continue }
            let updated = outdent ? removingLeadingIndent(from: line) : "  " + line
            let delta = updated.utf16.count - line.utf16.count
            if index == 0 { firstDelta = delta }
            totalDelta += delta
            lines[index] = updated
        }
        guard totalDelta != 0 else { return nil }

        let location = max(block.location, selection.location + firstDelta)
        let length = max(0, selection.length + totalDelta - firstDelta)
        return Edit(
            range: block, replacement: lines.joined(separator: "\n"),
            selection: NSRange(location: location, length: length)
        )
    }
}
