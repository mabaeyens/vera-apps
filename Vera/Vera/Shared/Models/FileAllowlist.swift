import Foundation

/// Decides which files the sidebar lists. Folders are always listed; a file is listed only
/// when Vera can open it. Order: the binary list wins, then the allowlist (fast, no I/O),
/// then a content sniff for anything unrecognised.
enum FileAllowlist {
    private static let extensions: Set<String> = [
        // Docs
        "md", "markdown", "mdx", "txt", "text", "rtf", "rst", "adoc", "org", "tex", "bib", "log", "csv", "tsv",
        // Data and config
        "json", "jsonc", "json5", "jsonl", "yaml", "yml", "toml", "ini", "cfg", "conf", "env", "properties",
        "plist", "entitlements", "xcconfig", "editorconfig",
        // Web
        "html", "htm", "xml", "xsd", "xsl", "svg", "css", "scss", "sass", "less",
        "js", "mjs", "cjs", "jsx", "ts", "tsx", "vue", "svelte",
        // Languages
        "swift", "m", "mm", "h", "hpp", "c", "cc", "cpp", "cs", "java", "kt", "kts", "go", "rs", "py", "pyi",
        "rb", "php", "pl", "lua", "r", "jl", "dart", "scala", "ex", "exs", "erl", "hs", "clj", "zig", "nim",
        // Shell and build
        "sh", "bash", "zsh", "fish", "ps1", "bat", "cmd", "make", "mk", "cmake", "gradle", "pro",
        "sql", "graphql", "proto",
        // Misc
        "diff", "patch", "lock", "service", "tf", "tfvars", "hcl", "gitignore", "gitattributes",
        "dockerignore", "pbxproj", "strings", "stringsdict", "xcstrings",
        // Wrappers (FileKind strips these before classifying)
        "template", "sample", "example", "dist", "orig",
        // Images (open in the viewer)
        "png", "jpg", "jpeg", "gif", "heic", "webp", "bmp",
    ]

    private static let names: Set<String> = [
        "makefile", "gnumakefile", "dockerfile", "containerfile", "procfile", "gemfile", "rakefile",
        "podfile", "fastfile", "brewfile", "vagrantfile", "jenkinsfile", "license", "licence", "copying",
        "notice", "readme", "changelog", "authors", "codeowners", "owners", "version",
    ]

    private static let dotFileNames: Set<String> = [
        ".editorconfig", ".npmrc", ".nvmrc", ".python-version", ".tool-versions", ".gitmodules",
    ]

    private static let dotFileSuffixes = ["rc", "ignore", "attributes", "profile", "env"]

    private static func isAllowlisted(_ name: String, ext: String) -> Bool {
        let lower = name.lowercased()
        if !ext.isEmpty { return extensions.contains(ext.lowercased()) }
        if names.contains(lower) { return true }
        if lower.hasPrefix(".") {
            return dotFileNames.contains(lower) || dotFileSuffixes.contains { lower.hasSuffix($0) }
        }
        return false
    }

    /// Whether the sidebar should list this file. Never throws: a file that can't be read
    /// is simply not listed unless the allowlist already vouched for it.
    nonisolated static func isListable(_ url: URL, downloadState: DownloadState, isLocal: Bool = true) -> Bool {
        if FileKind.classify(path: url.path) == .binary { return false }
        if isAllowlisted(url.lastPathComponent, ext: url.pathExtension) { return true }
        // Not downloaded yet: reading would trigger a download, so don't sniff.
        if downloadState == .cloud || !isLocal { return false }
        return looksLikeText(url)
    }

    /// First 4 KB: UTF-16 with a BOM, or no NUL byte. This matches what the loader can
    /// decode (UTF-8, UTF-16, Latin-1), so anything listed here opens.
    nonisolated private static func looksLikeText(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4096) else { return false }
        if data.isEmpty { return true }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) { return true }
        return !data.contains(0)
    }
}
