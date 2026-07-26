import Foundation

/// One match: either a file whose *name* matches, or a line whose *content* does.
struct SearchHit: Identifiable, Sendable, Hashable {
    let url: URL
    /// 1-based. Zero for a filename match, which has no line.
    let lineNumber: Int
    /// The matching line, trimmed for display. Empty for a filename match.
    let line: String
    let isFilenameMatch: Bool

    var id: String { "\(url.path)#\(lineNumber)#\(isFilenameMatch)" }
    var name: String { url.lastPathComponent }
}

/// Why a file wasn't searched, so the result set never quietly lies about its coverage.
enum SearchSkip: Sendable, Hashable {
    case notDownloaded(String)
    case tooLarge(String)
}

/// Content search across the opened folder.
///
/// Vera could already content-search a *connected GitHub repo* (through the API, inside the
/// browser modal) but not the local folder — the inverse of what's useful day to day.
///
/// Runs entirely off the main actor and streams hits as it finds them, so a large repo
/// shows its first matches immediately instead of blocking until the walk finishes.
enum FolderSearch {
    /// Stop after this many hits. Whatever the cap is, the UI says so — the existing
    /// GitHub search silently truncates at 30, which reads as "that's all there is".
    static let maxResults = 200

    /// Files above this are skipped rather than read into memory. Same ceiling the
    /// syntax highlighter uses.
    static let maxFileBytes = HighlightrEngine.maxHighlightBytes

    /// Directories never worth walking, whether or not a `.gitignore` mentions them.
    private static let alwaysSkip: Set<String> = [
        ".git", "node_modules", ".build", "DerivedData", ".next", "dist",
        "build", "Pods", ".venv", "venv", "__pycache__", ".swiftpm", ".idea",
    ]

    enum Event: Sendable {
        case hit(SearchHit)
        case skipped(SearchSkip)
        case truncated
        case finished
    }

    /// Walk `root` for `query`. Cancellation is honoured between files, so a per-keystroke
    /// restart drops the previous walk promptly.
    static func run(root: URL, query: String) -> AsyncStream<Event> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                let ignored = loadGitignore(at: root)
                var found = 0

                let keys: [URLResourceKey] = [
                    .isDirectoryKey, .fileSizeKey, .ubiquitousItemDownloadingStatusKey,
                ]
                guard let walker = FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else {
                    continuation.yield(.finished)
                    continuation.finish()
                    return
                }

                for case let url as URL in walker {
                    if Task.isCancelled { break }

                    let name = url.lastPathComponent
                    let values = try? url.resourceValues(forKeys: Set(keys))

                    if values?.isDirectory == true {
                        if alwaysSkip.contains(name) || ignored.contains(name) {
                            walker.skipDescendants()
                        }
                        continue
                    }
                    if ignored.contains(name) { continue }
                    // Only text Vera can actually open. Reuses the single editability
                    // gate rather than keeping a second list of extensions.
                    guard FileKind.classify(path: url.path).isEditable else { continue }

                    if name.localizedCaseInsensitiveContains(query) {
                        continuation.yield(.hit(SearchHit(
                            url: url, lineNumber: 0, line: "", isFilenameMatch: true
                        )))
                        found += 1
                        if found >= maxResults { continuation.yield(.truncated); break }
                    }

                    if let size = values?.fileSize, size > maxFileBytes {
                        continuation.yield(.skipped(.tooLarge(name)))
                        continue
                    }
                    // An evicted iCloud file can't be searched. Say so rather than
                    // omitting it silently, and don't trigger a folder-wide download.
                    if values?.ubiquitousItemDownloadingStatus == .notDownloaded {
                        continuation.yield(.skipped(.notDownloaded(name)))
                        continue
                    }
                    guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }

                    var lineNumber = 0
                    var stop = false
                    for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                        lineNumber += 1
                        guard line.localizedCaseInsensitiveContains(query) else { continue }
                        continuation.yield(.hit(SearchHit(
                            url: url,
                            lineNumber: lineNumber,
                            line: line.trimmingCharacters(in: .whitespaces),
                            isFilenameMatch: false
                        )))
                        found += 1
                        if found >= maxResults {
                            continuation.yield(.truncated)
                            stop = true
                            break
                        }
                    }
                    if stop { break }
                }

                continuation.yield(.finished)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Names listed in the root `.gitignore`.
    ///
    /// Deliberately simple: one path component per line, `#` comments and blank lines
    /// dropped, trailing slashes trimmed, and anything containing a glob or a path
    /// separator ignored rather than half-honoured. It catches the cases that matter
    /// (build directories, dependency trees) without pretending to implement gitignore.
    private nonisolated static func loadGitignore(at root: URL) -> Set<String> {
        guard let text = try? String(
            contentsOf: root.appendingPathComponent(".gitignore"), encoding: .utf8
        ) else { return [] }

        var names: Set<String> = []
        for raw in text.split(separator: "\n") {
            var line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix("!") else { continue }
            if line.hasSuffix("/") { line.removeLast() }
            guard !line.contains("/"), !line.contains("*"), !line.contains("?") else { continue }
            names.insert(line)
        }
        return names
    }
}
