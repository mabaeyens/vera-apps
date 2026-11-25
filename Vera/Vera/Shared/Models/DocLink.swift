import Foundation

/// A link in a rendered Markdown document that Vera navigates itself, as opposed to an
/// external URL the system opens.
enum DocLink: Equatable, Sendable {
    /// `[text](notes/other.md#heading)`: a path relative to the current file.
    case relative(path: String, fragment: String?)
    /// `[[Note]]`, `[[Note#Heading]]`: a note found by name anywhere in the folder.
    case wiki(name: String, fragment: String?)
    /// `[text](#heading)`: a heading in this same document.
    case anchor(String)

    static let wikiScheme = "vera-wiki"

    /// nil for anything external (https, mailto, ...), which the system should open.
    static func classify(_ url: URL) -> DocLink? {
        let fragment = url.fragment(percentEncoded: false).flatMap { $0.isEmpty ? nil : $0 }
        if url.scheme == wikiScheme {
            let name = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
            return name.isEmpty ? nil : .wiki(name: name, fragment: fragment)
        }
        guard url.scheme == nil || url.scheme?.isEmpty == true else { return nil }
        if url.path.isEmpty {
            return fragment.map { .anchor($0) }
        }
        return .relative(path: url.path, fragment: fragment)
    }
}

enum WikiLinks {
    private static let pattern = #"\[\[([^\[\]|#]+)(?:#([^\[\]|]+))?(?:\|([^\[\]]+))?\]\]"#

    /// Rewrite `[[Note]]`, `[[Note#Heading]]` and `[[Note|label]]` into ordinary Markdown
    /// links on the `vera-wiki` scheme, which the renderer then hands back to Vera. Text
    /// inside inline code spans is left alone, so a document *about* wikilinks reads right.
    nonisolated static func rewrite(_ markdown: String) -> String {
        guard markdown.contains("[["),
              let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }

        return markdown
            .components(separatedBy: "\n")
            .map { line -> String in
                guard line.contains("[[") else { return line }
                // Even-indexed pieces are outside backticks; odd ones are inside a code span.
                return line.components(separatedBy: "`").enumerated().map { index, piece in
                    index % 2 == 0 ? rewritePiece(piece, regex: regex) : piece
                }.joined(separator: "`")
            }
            .joined(separator: "\n")
    }

    private nonisolated static func rewritePiece(_ piece: String, regex: NSRegularExpression) -> String {
        let ns = piece as NSString
        var result = ""
        var last = 0
        for match in regex.matches(in: piece, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            func group(_ i: Int) -> String? {
                let r = match.range(at: i)
                return r.location == NSNotFound ? nil : ns.substring(with: r)
                    .trimmingCharacters(in: .whitespaces)
            }
            let name = group(1) ?? ""
            let label = group(3) ?? name
            var components = URLComponents()
            components.scheme = DocLink.wikiScheme
            components.path = "/" + name
            components.fragment = group(2)
            // Parentheses would end the Markdown link destination early.
            let destination = (components.string ?? "")
                .replacingOccurrences(of: "(", with: "%28")
                .replacingOccurrences(of: ")", with: "%29")
            result += "[\(label)](\(destination))"
            last = match.range.location + match.range.length
        }
        result += ns.substring(from: last)
        return result
    }
}

/// GitHub-style heading slug: lowercased, punctuation dropped, spaces to hyphens. Used to
/// match `#fragment` links against headings.
nonisolated func headingSlug(_ heading: String) -> String {
    let kept = heading.lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" || $0 == "_" }
    return kept.replacingOccurrences(of: " ", with: "-")
}

/// Every editable file under the opened folder, found by a background walk. Wikilinks
/// and the quick switcher both need this: the sidebar tree is loaded lazily, one level at
/// a time, so it can't answer "where is the note called X".
enum FileIndex {
    static let maxFiles = 20_000

    static func build(root: URL) async -> [URL] {
        await Task.detached(priority: .userInitiated) {
            guard let walker = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: Defaults.showHiddenFiles ? [.skipsPackageDescendants] : [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return [] }

            var files: [URL] = []
            while let url = walker.nextObject() as? URL {
                if Task.isCancelled || files.count >= maxFiles { break }
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    if FolderSearch.alwaysSkip.contains(url.lastPathComponent) { walker.skipDescendants() }
                    continue
                }
                if url.lastPathComponent == ".DS_Store" { continue }
                guard FileKind.classify(path: url.path).isEditable else { continue }
                files.append(url)
            }
            return files
        }.value
    }

    /// Pick the file a wikilink means. Matches the base name case-insensitively (a
    /// `folder/Note` target must also match the folder), and when several notes share a
    /// name prefers the one closest to `current`, then the shortest path.
    static func resolveWiki(name: String, in files: [URL], near current: URL, root: URL) -> URL? {
        let wanted = name.lowercased()
        let wantedBase = (wanted as NSString).deletingPathExtension
        let currentDir = current.deletingLastPathComponent().path

        let matches = files.filter { url in
            let relative = relativePath(of: url, to: root).lowercased()
            let noExt = (relative as NSString).deletingPathExtension
            return noExt == wantedBase || noExt.hasSuffix("/" + wantedBase)
        }
        return matches.min { a, b in
            let da = sharedPrefixLength(a.deletingLastPathComponent().path, currentDir)
            let db = sharedPrefixLength(b.deletingLastPathComponent().path, currentDir)
            if da != db { return da > db }
            let ha = hiddenRank(a, root: root), hb = hiddenRank(b, root: root)
            if ha != hb { return ha < hb }
            return a.path.count < b.path.count
        }
    }

    /// 1 when the file sits under a dot-named component below `root`, else 0.
    private static func hiddenRank(_ url: URL, root: URL) -> Int {
        relativePath(of: url, to: root).split(separator: "/").contains { $0.hasPrefix(".") } ? 1 : 0
    }

    static func relativePath(of url: URL, to root: URL) -> String {
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return url.path.hasPrefix(prefix) ? String(url.path.dropFirst(prefix.count)) : url.lastPathComponent
    }

    private static func sharedPrefixLength(_ a: String, _ b: String) -> Int {
        zip(a, b).prefix { $0 == $1 }.count
    }
}
