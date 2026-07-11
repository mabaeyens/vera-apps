import Foundation
import Observation

enum EditorMode { case viewing, editing }

@Observable
@MainActor
final class EditorViewModel {
    var mode: EditorMode = .viewing
    var rawText: String = ""
    var isLoading = false
    var saveState: SaveState = .saved
    var anchorFraction: CGFloat? = nil
    var readingScrollFraction: CGFloat = 0
    var insertAtCursor: ((String) -> Void)? = nil
    var wrapSelection: ((String, String) -> Void)? = nil
    var stripSelection: (() -> Void)? = nil
    var atlasRequested = false
    var lintResults: [LintWarning] = []

    // `.uncommitted`/`.committing` apply only to GitHub sources (no autosave there).
    enum SaveState { case saved, saving, error(String), uncommitted, committing }

    let source: DocumentSource
    private(set) var blobSHA: String?       // GitHub: current file blob SHA, for commits

    /// The document's format, derived from its path extension. nil for anything outside
    /// the 4 editable formats — including the read-only files the tree now browses
    /// (source code, `.entitlements`, etc.) — callers gate editing on this being non-nil.
    var format: DocumentFormat? {
        switch source {
        case .file(let url): return DocumentFormat.from(extension: url.pathExtension)
        case .gitHub(let ref): return DocumentFormat.from(path: ref.path)
        }
    }

    var isUncommitted: Bool {
        if case .uncommitted = saveState { return true }
        return false
    }

    // MARK: - Focus Mode highlighting

    /// Files the user has opted out of live syntax highlighting while in Focus Mode.
    /// Keyed by `DocumentSource.id` so the choice survives relaunches per file. Stored as
    /// an array, most-recently-set first, and capped so this can't grow unboundedly as
    /// files are opted in/out over the app's lifetime — the oldest entry is dropped once
    /// the cap is exceeded rather than tracking every delete/rename/disconnect elsewhere.
    private static let focusModePlainTextFilesLimit = 500

    private var focusModePlainTextFiles: [String] {
        get { UserDefaults.standard.stringArray(forKey: Defaults.Key.focusModePlainTextFiles) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Defaults.Key.focusModePlainTextFiles) }
    }

    /// Whether this file is currently opted out of highlighting while Focus Mode is on.
    var isPlainTextInFocusMode: Bool {
        focusModePlainTextFiles.contains(source.id)
    }

    func setPlainTextInFocusMode(_ plain: Bool) {
        var files = focusModePlainTextFiles
        files.removeAll { $0 == source.id }
        if plain {
            files.insert(source.id, at: 0)
            if files.count > Self.focusModePlainTextFilesLimit {
                files.removeLast(files.count - Self.focusModePlainTextFilesLimit)
            }
        }
        focusModePlainTextFiles = files
    }

    /// Highlightr language key for the live editor. `nil` disables highlighting
    /// (plain monospace text). Suppressed for this file while Focus Mode is on and the
    /// user has opted this file out; otherwise falls back to the document format's
    /// language (`DocumentFormat.highlightLanguage`).
    func highlightLanguage(focusMode: Bool) -> String? {
        if focusMode && isPlainTextInFocusMode { return nil }
        return format?.highlightLanguage
    }

    var wordCount: Int {
        rawText.split { $0.isWhitespace || $0.isNewline }.count
    }

    var characterCount: Int {
        rawText.count
    }

    /// nil when there's no text, so the UI can omit reading time for empty docs.
    var estimatedReadingTime: String? {
        guard wordCount > 0 else { return nil }
        let minutes = max(1, Int((Double(wordCount) / 200.0).rounded()))
        return "~\(minutes) min read"
    }

    /// Base URL for resolving relative image/link paths in the rendered preview —
    /// the doc's raw GitHub content directory, or its containing local folder.
    var previewBaseURL: URL? {
        switch source {
        case .file(let url):
            return url.deletingLastPathComponent()
        case .gitHub(let ref):
            let dir = (ref.path as NSString).deletingLastPathComponent
            var components = URLComponents()
            components.scheme = "https"
            components.host = "raw.githubusercontent.com"
            components.path = dir.isEmpty
                ? "/\(ref.owner)/\(ref.repo)/\(ref.branch)/"
                : "/\(ref.owner)/\(ref.repo)/\(ref.branch)/\(dir)/"
            return components.url
        }
    }

    private var saveTask: Task<Void, Never>?
    private var lintTask: Task<Void, Never>?

    init(source: DocumentSource) {
        self.source = source
    }

    convenience init(url: URL) {
        self.init(source: .file(url))
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        switch source {
        case .file(let url): await loadFile(url)
        case .gitHub(let ref): await loadGitHub(ref)
        }
        if rawText.isEmpty && format != nil { mode = .editing }
        scheduleLint()
    }

    private func loadFile(_ url: URL) async {
        do {
            rawText = try await DocumentStore.read(url)
        } catch {
            // Only retry if this is genuinely an iCloud item still downloading — a file
            // that's already local (or not an iCloud item at all) failed to decode as
            // UTF-8 text for a real reason (e.g. a binary file the tree now shows
            // optimistically as read-only text) and retrying for 15s would just stall.
            let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                .ubiquitousItemDownloadingStatus
            guard status == .notDownloaded else {
                rawText = ""
                return
            }
            for _ in 0..<15 {
                try? await Task.sleep(for: .seconds(1))
                let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                    .ubiquitousItemDownloadingStatus
                if status == .current || status == .downloaded {
                    rawText = (try? await DocumentStore.read(url)) ?? ""
                    return
                }
            }
            rawText = ""
        }
    }

    private func loadGitHub(_ ref: GitHubFileRef) async {
        if let cached = GitHubFileCache.lookup(ref) {
            rawText = cached.text
            blobSHA = cached.sha
            return
        }
        guard let client = gitHubClient() else { rawText = ""; return }
        do {
            let version = try await client.fileVersion(path: ref.path, ref: ref.branch)
            rawText = version.text
            blobSHA = version.sha
            GitHubFileCache.store(ref, text: version.text, sha: version.sha)
        } catch {
            saveState = .error(error.localizedDescription)
            rawText = ""
        }
    }

    func enterEditMode(tapY: CGFloat = 0, viewHeight: CGFloat = 0) {
        guard format != nil else { return }
        if viewHeight > 0 {
            anchorFraction = tapY / viewHeight
        } else {
            // Toolbar Edit button: use the current reading scroll position
            anchorFraction = readingScrollFraction > 0 ? readingScrollFraction : nil
        }
        mode = .editing
    }

    func exitEditMode() {
        mode = .viewing
        anchorFraction = nil
    }

    func insertSnippet(_ snippet: String) {
        if let insert = insertAtCursor {
            insert(snippet)
        } else {
            rawText += "\n\(snippet)"
            textDidChange()
        }
    }

    func stripAtCursor() {
        stripSelection?()
    }

    func wrapOrInsert(_ syntax: String, prefix: String, suffix: String) {
        if let wrap = wrapSelection {
            wrap(prefix, suffix)
        } else {
            insertSnippet(syntax)
        }
    }

    func applyAutoFix() {
        rawText = rawText.fixMarkdown()
        textDidChange()
    }

    func textDidChange() {
        switch source {
        case .file:
            saveState = .saving
            scheduleSave()
        case .gitHub:
            // No autosave — a commit is explicit. Just mark the buffer dirty.
            saveState = .uncommitted
        }
        scheduleLint()
    }

    // MARK: - GitHub source

    private func gitHubClient() -> GitHubClient? {
        guard case .gitHub(let ref) = source, let token = CredentialStore.load() else { return nil }
        return GitHubClient(owner: ref.owner, repo: ref.repo, token: token)
    }

    /// The most recent commit that touched this file (for the "What Changed" affordance).
    func latestCommit() async -> GitHubCommit? {
        guard case .gitHub(let ref) = source, let client = gitHubClient() else { return nil }
        return try? await client.latestCommit(path: ref.path)
    }

    /// Recent commit history for this file, for the "What Changed" sheet's history list.
    func commitHistory(limit: Int = 20) async throws -> [GitHubCommit] {
        guard case .gitHub(let ref) = source, let client = gitHubClient() else { return [] }
        return try await client.commits(path: ref.path, limit: limit)
    }

    func diff(from base: String, to head: String) async throws -> String? {
        guard case .gitHub(let ref) = source, let client = gitHubClient() else { return nil }
        return try await client.diff(path: ref.path, from: base, to: head)
    }

    /// Commit the current text. `openPR` true → create a branch and open a PR; false →
    /// commit straight to the file's branch. Returns the GitHub URL to show, if any.
    /// Commit the current text. `openPR` true → create a branch and open a PR into `targetBranch`;
    /// false → commit straight to `targetBranch`. Returns the GitHub URL to show, if any.
    func commit(message: String, openPR: Bool, targetBranch: String? = nil) async throws -> URL? {
        guard case .gitHub(let ref) = source, let client = gitHubClient(), let sha = blobSHA else {
            return nil
        }
        let commitBranch = targetBranch ?? ref.branch
        saveState = .committing
        do {
            let urlString: String?
            if openPR {
                let base = commitBranch
                let head = "vera/\(slug(ref.path))-\(Int(Date().timeIntervalSince1970))"
                // Fork the working branch from the PR's base, not the branch the file
                // was opened on, so the PR diff contains only this file's edit.
                let baseSHA = try await client.headSHA(branch: base)
                try await client.createBranch(name: head, fromSHA: baseSHA)
                try await client.commitFile(path: ref.path, message: message, text: rawText, sha: sha, branch: head)
                urlString = try await client.openPullRequest(title: message, body: "Edited in Vera.", head: head, base: base)
                // The viewed branch is unchanged, so blobSHA stays valid.
            } else {
                // blobSHA was read on ref.branch. If committing to a different branch,
                // it wasn't read there, so fetch that branch's current SHA first —
                // otherwise the mismatched SHA gets rejected as a false conflict.
                let commitSHA: String
                if commitBranch == ref.branch {
                    commitSHA = sha
                } else {
                    commitSHA = try await client.fileVersion(path: ref.path, ref: commitBranch).sha
                }
                urlString = try await client.commitFile(path: ref.path, message: message, text: rawText, sha: commitSHA, branch: commitBranch)
                // Refresh the blob SHA so a follow-up commit isn't rejected as stale —
                // only when committing to the branch this editor tracks (ref.branch);
                // otherwise blobSHA would end up describing a different branch entirely.
                if commitBranch == ref.branch, let version = try? await client.fileVersion(path: ref.path, ref: commitBranch) {
                    blobSHA = version.sha
                }
            }
            // The committed branch's cached content is now stale; the PR-branch case
            // doesn't touch commitBranch's own content, so nothing to invalidate there.
            if !openPR {
                GitHubFileCache.invalidate(GitHubFileRef(owner: ref.owner, repo: ref.repo, path: ref.path, branch: commitBranch))
            }
            saveState = .saved
            return urlString.flatMap(URL.init(string:))
        } catch {
            saveState = .uncommitted
            throw error
        }
    }

    /// Fetch all branch names for the repo; used to populate the commit sheet's branch picker.
    func fetchBranches() async -> [String] {
        guard let client = gitHubClient() else { return [] }
        return (try? await client.branches()) ?? []
    }

    /// Fetch the current text of this file from GitHub (used to show the remote version
    /// on a 409 conflict so the user can compare before overwriting). `branch` should be
    /// the branch the failed commit actually targeted, which may differ from the branch
    /// this file was opened on.
    func fetchRemoteText(branch: String? = nil) async throws -> String {
        guard case .gitHub(let ref) = source, let client = gitHubClient() else {
            throw GitHubError.decoding
        }
        let (text, _) = try await client.fileVersion(path: ref.path, ref: branch ?? ref.branch)
        return text
    }

    /// Re-fetch the current blob SHA then commit the user's text, effectively
    /// force-overwriting whatever was committed after the user opened the file.
    func overwriteCommit(message: String, openPR: Bool, targetBranch: String? = nil) async throws -> URL? {
        guard case .gitHub(let ref) = source, let client = gitHubClient() else { return nil }
        let branch = targetBranch ?? ref.branch
        let (_, freshSHA) = try await client.fileVersion(path: ref.path, ref: branch)
        blobSHA = freshSHA
        return try await commit(message: message, openPR: openPR, targetBranch: branch)
    }

    private func slug(_ path: String) -> String {
        let name = (path as NSString).lastPathComponent.lowercased().replacingOccurrences(of: " ", with: "-")
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-")
        return String(name.filter { allowed.contains($0) }.prefix(40))
    }

    // MARK: - Private

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            await self.flush()
        }
    }

    /// Persist any pending edit immediately, bypassing the debounce. Call this when the
    /// editor view disappears (tab switch / navigation) so the last keystrokes — still
    /// inside the 500 ms debounce window — are never silently dropped.
    func flushPendingSave() async {
        guard case .file = source, case .saving = saveState else { return }
        saveTask?.cancel()
        await flush()
    }

    private func scheduleLint() {
        let enabled = UserDefaults.standard.object(forKey: Defaults.Key.linterEnabled) == nil
            ? true : UserDefaults.standard.bool(forKey: Defaults.Key.linterEnabled)
        guard enabled else {
            lintResults = []
            return
        }
        lintTask?.cancel()
        let snapshot = rawText
        let kind = FileKind.classify(path: source.path)
        lintTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            // Run the line scan off the main actor — for large files it's heavy
            // enough to stutter typing if left on the EditorViewModel's @MainActor.
            let results = await Task.detached {
                switch kind {
                case .editable(.markdown): return snapshot.lintMarkdown()
                case .editable(.json): return snapshot.lintJSON() + snapshot.lintGenericHygiene()
                case .editable(.yaml): return snapshot.lintYAML() + snapshot.lintGenericHygiene()
                case .editable(.text): return snapshot.lintGenericHygiene()
                case .readOnlyText: return snapshot.lintGenericHygiene()
                case .image, .binary: return []
                }
            }.value
            guard !Task.isCancelled else { return }
            self?.lintResults = results
        }
    }

    private func flush() async {
        guard case .file(let url) = source else { return }
        do {
            try await DocumentStore.write(url, content: rawText)
            saveState = .saved
        } catch {
            saveState = .error(error.localizedDescription)
        }
    }
}
