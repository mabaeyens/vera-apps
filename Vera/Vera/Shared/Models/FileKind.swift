import Foundation

/// How a file, by extension, should be treated when browsing a folder or repo.
/// `DocumentFormat` (the 4 live-editable formats) is unchanged and unaffected — this
/// classifier layers a broader, read-only-by-default set on top of it, so a file tree
/// can show (and a viewer can render) far more than what's actually editable.
enum FileKind: Equatable {
    /// One of the 4 formats Vera can live-edit and commit.
    case editable(DocumentFormat)
    /// Any other recognized text file — view + syntax-highlight only, never editable.
    /// `language` is a Highlightr grammar id, or nil if the extension has no known grammar
    /// (still rendered, just as plain monospace text).
    case readOnlyText(language: String?)
    case image
    case binary

    /// The Highlightr language for a read-only text file, or nil for anything else
    /// (including editable formats, which use `DocumentFormat.highlightLanguage` instead).
    var readOnlyLanguage: String? {
        if case .readOnlyText(let language) = self { return language }
        return nil
    }

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
        "js": "javascript", "javascript": "javascript",
        "ts": "typescript", "typescript": "typescript",
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

    static func classify(extension ext: String) -> FileKind {
        let lower = ext.lowercased()
        if let format = DocumentFormat.from(extension: lower) { return .editable(format) }
        if imageExtensions.contains(lower) { return .image }
        if binaryExtensions.contains(lower) { return .binary }
        return .readOnlyText(language: languageMap[lower])
    }

    static func classify(path: String) -> FileKind {
        classify(extension: (path as NSString).pathExtension)
    }
}
