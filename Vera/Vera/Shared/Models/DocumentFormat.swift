import Foundation

/// The text-based file formats Vera can browse, read, edit, and commit. Markdown is
/// the primary format (rich preview, linting, auto-fix); the others are read/edited as
/// plain or syntax-highlighted text — no markdown-specific behavior applies to them.
enum DocumentFormat: String, CaseIterable {
    case markdown
    case text
    case json
    case yaml

    /// Recognized extensions (lowercased, no leading dot) for this format.
    var extensions: [String] {
        switch self {
        case .markdown: return ["md", "markdown"]
        case .text: return ["txt"]
        case .json: return ["json"]
        case .yaml: return ["yaml", "yml"]
        }
    }

    /// Extension used when creating a new file of this format.
    var defaultExtension: String { extensions[0] }

    var label: String {
        switch self {
        case .markdown: return "Markdown"
        case .text: return "Text"
        case .json: return "JSON"
        case .yaml: return "YAML"
        }
    }

    /// SF Symbol for sidebar/file rows. Markdown keeps the dedicated Markdown-mark asset.
    var systemImage: String {
        switch self {
        case .markdown: return "" // unused — markdown rows use MarkdownFileIcon instead
        case .text: return "doc.plaintext"
        case .json: return "curlybraces"
        case .yaml: return "list.bullet.rectangle"
        }
    }

    /// Highlightr language key for syntax-highlighted preview (nil = plain text).
    var highlightLanguage: String? {
        switch self {
        case .markdown: return "markdown"
        case .json: return "json"
        case .yaml: return "yaml"
        case .text: return nil
        }
    }

    static var allExtensions: Set<String> {
        Set(allCases.flatMap(\.extensions))
    }

    static func from(extension ext: String) -> DocumentFormat? {
        let lower = ext.lowercased()
        return allCases.first { $0.extensions.contains(lower) }
    }

    static func from(path: String) -> DocumentFormat? {
        from(extension: (path as NSString).pathExtension)
    }
}
