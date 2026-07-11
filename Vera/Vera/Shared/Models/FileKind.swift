import Foundation

/// How a file, by extension, should be treated when browsing a folder or repo.
/// `DocumentFormat` (the 4 live-editable formats) is unchanged and unaffected — this
/// classifier layers a broader, read-only-by-default set on top of it, so a file tree
/// can show (and a viewer can render) far more than what's actually editable.
enum FileKind: Equatable {
    /// One of the 4 formats Vera can live-edit and commit, with format-specific handling
    /// (Markdown preview/auto-fix, JSON/YAML-specific lint).
    case editable(DocumentFormat)
    /// Any other recognized text file — also editable (see `isEditable`), just without
    /// any format-specific handling. `language` is a Highlightr grammar id, or nil if the
    /// extension has no known grammar (still rendered/edited, just as plain monospace
    /// text). Named `readOnlyText` from when this case predated general editability;
    /// kept to avoid a wide rename with no functional benefit.
    case readOnlyText(language: String?)
    case image
    case binary

    /// Whether a file of this kind can be opened in the live editor at all. `false` only
    /// for images and binaries — every text kind, editable-format or not, is editable.
    var isEditable: Bool {
        switch self {
        case .editable, .readOnlyText: return true
        case .image, .binary: return false
        }
    }

    /// The Highlightr language for a non-`DocumentFormat` text file, or nil for anything
    /// else (including editable formats, which use `DocumentFormat.highlightLanguage`
    /// instead).
    var readOnlyLanguage: String? {
        if case .readOnlyText(let language) = self { return language }
        return nil
    }

    /// Best-available SF Symbol for this kind, for file-tree row icons. There's no
    /// dedicated SF Symbol for most languages (Python, Swift, etc.) — those fall back to
    /// a generic code-brackets glyph; only languages with a meaningfully different symbol
    /// get one. `.editable(.markdown)` isn't handled here — callers use the custom
    /// `MarkdownFileIcon` asset for that case instead.
    var systemImage: String {
        switch self {
        case .editable(let format): return format.systemImage
        case .readOnlyText(let language):
            return language.flatMap { Self.readOnlySystemImages[$0] } ?? "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        case .binary: return "doc"
        }
    }

    private static let readOnlySystemImages: [String: String] = [
        "bash": "terminal", "powershell": "terminal",
        "json": "curlybraces",
        "yaml": "list.bullet.rectangle", "toml": "list.bullet.rectangle",
        "sql": "cylinder",
    ]

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "heic", "webp", "bmp"
    ]

    /// Extensions known to be binary/non-text, shown in the tree but inert when tapped.
    /// Not exhaustive — anything not recognized here or above falls through to
    /// `.readOnlyText`, which is the safer default for an unfamiliar extension.
    private static let binaryExtensions: Set<String> = [
        "dmg", "zip", "gz", "tar", "exe", "app", "ipa", "pkg",
        "ttf", "otf", "woff", "woff2",
        "pdf", "mp3", "mp4", "mov", "wav",
        "ico", "icns", "a", "o", "dylib"
    ]

    /// Extension (or loose language name) → Highlightr grammar id. Shared by the
    /// read-only tree viewer (`FileKind`) and the fenced-code-block renderer
    /// (`HighlightedCodeView`), so a new mapping only needs to be added once.
    static let languageMap: [String: String] = [
        "py": "python", "python": "python",
        "rb": "ruby", "ruby": "ruby",
        "js": "javascript", "javascript": "javascript", "cjs": "javascript",
        "ts": "typescript", "typescript": "typescript", "tsx": "typescript",
        "swift": "swift",
        "kotlin": "kotlin", "kt": "kotlin",
        "java": "java",
        "c": "c", "cpp": "cpp", "c++": "cpp",
        "cs": "csharp", "csharp": "csharp",
        "go": "go",
        "rs": "rust", "rust": "rust",
        "sh": "bash", "bash": "bash", "zsh": "bash",
        "ps1": "powershell", "powershell": "powershell",
        "sql": "sql",
        "html": "html", "xml": "xml",
        "css": "css", "scss": "scss",
        "json": "json",
        "yaml": "yaml", "yml": "yaml",
        "toml": "toml",
        "md": "markdown", "markdown": "markdown",
        "r": "r",
        "dockerfile": "dockerfile",
        "entitlements": "xml", "plist": "xml",
    ]

    /// A file named e.g. `config.yaml.template` should still highlight as YAML — these
    /// wrapper extensions are stripped so classification falls through to the extension
    /// one level in, but the result always stays read-only (never `.editable`), even if
    /// the inner extension is one of the 4 editable formats: only an exact match on one
    /// of those 4 extensions is ever live-editable.
    private static let wrapperExtensions: Set<String> = ["template", "sample", "example", "dist", "orig"]

    static func classify(extension ext: String) -> FileKind {
        let lower = ext.lowercased()
        if let format = DocumentFormat.from(extension: lower) { return .editable(format) }
        if imageExtensions.contains(lower) { return .image }
        if binaryExtensions.contains(lower) { return .binary }
        return .readOnlyText(language: languageMap[lower])
    }

    static func classify(path: String) -> FileKind {
        let ns = path as NSString
        let ext = ns.pathExtension.lowercased()
        if wrapperExtensions.contains(ext) {
            let inner = (ns.deletingPathExtension as NSString).pathExtension
            if !inner.isEmpty {
                switch classify(extension: inner) {
                case .editable(let format): return .readOnlyText(language: format.highlightLanguage)
                case let other: return other
                }
            }
        }
        return classify(extension: ext)
    }
}
