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
    private var blobSHA: String?            // GitHub: current file blob SHA, for commits
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
        if rawText.isEmpty { mode = .editing }
    }

    private func loadFile(_ url: URL) async {
        do {
            rawText = try await DocumentStore.read(url)
        } catch {
            // File may be an iCloud item mid-download; poll until available (up to 15 s).
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
        guard let client = gitHubClient() else { rawText = ""; return }
        do {
            let version = try await client.fileVersion(path: ref.path, ref: ref.branch)
            rawText = version.text
            blobSHA = version.sha
        } catch {
            saveState = .error(error.localizedDescription)
            rawText = ""
        }
    }

    func enterEditMode(tapY: CGFloat = 0, viewHeight: CGFloat = 0) {
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

    func diff(from base: String, to head: String) async throws -> String? {
        guard case .gitHub(let ref) = source, let client = gitHubClient() else { return nil }
        return try await client.diff(path: ref.path, from: base, to: head)
    }

    /// Commit the current text. `openPR` true → create a branch and open a PR; false →
    /// commit straight to the file's branch. Returns the GitHub URL to show, if any.
    func commit(message: String, openPR: Bool) async throws -> URL? {
        guard case .gitHub(let ref) = source, let client = gitHubClient(), let sha = blobSHA else {
            return nil
        }
        saveState = .committing
        do {
            let urlString: String?
            if openPR {
                let base = ref.branch
                let head = "vera/\(slug(ref.path))-\(Int(Date().timeIntervalSince1970))"
                let baseSHA = try await client.headSHA(branch: base)
                try await client.createBranch(name: head, fromSHA: baseSHA)
                try await client.commitFile(path: ref.path, message: message, text: rawText, sha: sha, branch: head)
                urlString = try await client.openPullRequest(title: message, body: "Edited in Vera.", head: head, base: base)
                // The viewed branch is unchanged, so blobSHA stays valid.
            } else {
                urlString = try await client.commitFile(path: ref.path, message: message, text: rawText, sha: sha, branch: ref.branch)
                // Refresh the blob SHA so a follow-up commit isn't rejected as stale.
                if let version = try? await client.fileVersion(path: ref.path, ref: ref.branch) {
                    blobSHA = version.sha
                }
            }
            saveState = .saved
            return urlString.flatMap(URL.init(string:))
        } catch {
            saveState = .uncommitted
            throw error
        }
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

    private func scheduleLint() {
        let enabled = UserDefaults.standard.object(forKey: "linterEnabled") == nil
            ? true : UserDefaults.standard.bool(forKey: "linterEnabled")
        guard enabled else {
            lintResults = []
            return
        }
        lintTask?.cancel()
        let snapshot = rawText
        lintTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let results = snapshot.lintMarkdown()
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
