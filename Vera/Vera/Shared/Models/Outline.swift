import Foundation

struct OutlineItem: Identifiable, Sendable, Equatable {
    let id: Int
    /// 1 for `#`, up to 6.
    let level: Int
    let title: String
    /// Matches the anchor the preview registers for this heading, duplicates included.
    let slug: String
    /// UTF-16 offset of the heading line's start, for scrolling the editor.
    let offset: Int
}

/// The heading text of an ATX heading line, without the leading and trailing `#`s.
nonisolated func headingTitle(_ line: String) -> String {
    line.drop { $0 == " " }.drop { $0 == "#" }
        .trimmingCharacters(in: .whitespaces)
        .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        .trimmingCharacters(in: .whitespaces)
}

enum Outline {
    /// Headings in document order. Skips fenced code, so a `# comment` in a shell block
    /// is not a heading. Slugs are de-duplicated the way the preview does it
    /// (`intro`, `intro-1`, `intro-2`), so an outline entry always scrolls to its own heading.
    nonisolated static func items(in text: String) -> [OutlineItem] {
        var items: [OutlineItem] = []
        var seen: [String: Int] = [:]
        var inFence = false
        var offset = 0

        for line in text.components(separatedBy: "\n") {
            defer { offset += line.utf16.count + 1 }
            if line.drop(while: { $0 == " " || $0 == "\t" }).hasPrefix("```") {
                inFence.toggle()
                continue
            }
            guard !inFence, isHeadingLine(line) else { continue }
            let title = headingTitle(line)
            guard !title.isEmpty else { continue }

            var slug = headingSlug(title)
            if let count = seen[slug] {
                seen[slug] = count + 1
                slug += "-\(count)"
            } else {
                seen[slug] = 1
            }
            let level = line.drop { $0 == " " }.prefix { $0 == "#" }.count
            items.append(OutlineItem(id: items.count, level: level, title: title, slug: slug, offset: offset))
        }
        return items
    }
}
