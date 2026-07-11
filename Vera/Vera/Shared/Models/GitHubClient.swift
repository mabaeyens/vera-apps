import Foundation

/// A Markdown file inside a GitHub repository.
struct GitHubItem: Identifiable, Hashable {
    let path: String
    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
}

/// A file returned by GitHub Code Search, with an optional matched content fragment.
struct CodeSearchResult: Identifiable {
    let path: String
    let fragment: String?
    var id: String { path }
}

/// A commit that touched a given file. (Spec C2.)
struct GitHubCommit: Identifiable, Hashable {
    let sha: String
    let message: String
    let authorName: String
    let date: Date?
    var id: String { sha }

    /// First line of the commit message.
    var summary: String { message.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? message }
    var shortSHA: String { String(sha.prefix(7)) }
}

enum GitHubError: LocalizedError {
    case badResponse(Int)
    case notMarkdown
    case decoding
    case conflict
    case noToken
    case contentTooLarge

    var errorDescription: String? {
        switch self {
        case .badResponse(let code):
            if code == 401 { return "GitHub rejected the token. Check it has access to this repo." }
            if code == 404 { return "Repository or path not found." }
            return "GitHub returned an error (\(code))."
        case .notMarkdown: return "That file isn't Markdown."
        case .decoding: return "Couldn't read GitHub's response."
        case .conflict: return "The file changed on GitHub since you opened it."
        case .noToken: return "Sign in to GitHub before creating a file here."
        case .contentTooLarge: return "This file is too large to preview (over 1 MB)."
        }
    }
}

/// Minimal, read-only GitHub REST client. Talks directly to api.github.com with a
/// fine-grained PAT — no backend, nothing routed through us. (Spec C1.)
struct GitHubClient {
    let owner: String
    let repo: String
    let token: String

    private static let apiBase = "https://api.github.com"

    /// Build a request to `path` with the standard GitHub auth + version headers.
    private func request(_ path: String, method: String = "GET") throws -> URLRequest {
        guard let url = URL(string: Self.apiBase + path) else { throw GitHubError.badResponse(0) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        return req
    }

    private func get(_ path: String) async throws -> Data {
        let req = try request(path)
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw GitHubError.badResponse(code) }
        return data
    }

    /// Send a JSON body (PUT/POST). Used by the write path (Spec C3).
    private func send(_ method: String, _ path: String, body: [String: Any]) async throws -> Data {
        var req = try request(path, method: method)
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 409 { throw GitHubError.conflict }
        guard (200...299).contains(code) else { throw GitHubError.badResponse(code) }
        return data
    }

    private struct RepoMeta: Decodable { let default_branch: String }
    private struct BranchDTO: Decodable { let name: String }
    private struct Tree: Decodable {
        struct Node: Decodable { let path: String; let type: String }
        let tree: [Node]
    }
    private struct Contents: Decodable { let content: String; let encoding: String; let sha: String; let size: Int }
    private struct RefDTO: Decodable { let object: Object; struct Object: Decodable { let sha: String } }
    private struct WriteResponse: Decodable { let commit: Commit; struct Commit: Decodable { let html_url: String? } }
    private struct PullResponse: Decodable { let html_url: String? }

    private struct CommitDTO: Decodable {
        let sha: String
        let commit: Commit
        struct Commit: Decodable {
            let message: String
            let author: Author
            struct Author: Decodable { let name: String; let date: String }
        }
    }
    private struct SearchResponse: Decodable {
        let items: [SearchItem]
        struct SearchItem: Decodable {
            let path: String
            let text_matches: [TextMatch]?
            struct TextMatch: Decodable { let fragment: String }
        }
    }

    private struct CompareDTO: Decodable {
        let files: [FileChange]?
        struct FileChange: Decodable {
            let filename: String
            let status: String
            let patch: String?
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func defaultBranch() async throws -> String {
        let data = try await get("/repos/\(owner)/\(repo)")
        guard let meta = try? JSONDecoder().decode(RepoMeta.self, from: data) else { throw GitHubError.decoding }
        return meta.default_branch
    }

    /// All files in the repo (recursive), sorted by path. `FileKind.classify` decides
    /// per-file how each one is opened (editable/read-only/image/binary) — no filtering
    /// happens here.
    func documentFiles(branch: String) async throws -> [GitHubItem] {
        let data = try await get("/repos/\(owner)/\(repo)/git/trees/\(encode(path: branch))?recursive=1")
        guard let tree = try? JSONDecoder().decode(Tree.self, from: data) else { throw GitHubError.decoding }
        return tree.tree
            .filter { $0.type == "blob" }
            .map { GitHubItem(path: $0.path) }
            .sorted { $0.path.localizedCompare($1.path) == .orderedAscending }
    }

    private func encode(path: String) -> String {
        path.split(separator: "/")
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
    }

    /// Percent-encode a value for use in a URL query (slashes are legal in queries).
    private func encode(query value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    /// Commit history for a single file, newest first. (Spec C2.)
    func commits(path: String, limit: Int = 20) async throws -> [GitHubCommit] {
        let data = try await get("/repos/\(owner)/\(repo)/commits?path=\(encode(path: path))&per_page=\(limit)")
        guard let dtos = try? JSONDecoder().decode([CommitDTO].self, from: data) else { throw GitHubError.decoding }
        return dtos.map {
            GitHubCommit(
                sha: $0.sha,
                message: $0.commit.message,
                authorName: $0.commit.author.name,
                date: Self.isoFormatter.date(from: $0.commit.author.date)
            )
        }
    }

    /// The most recent commit that touched `path`, or nil if none.
    func latestCommit(path: String) async throws -> GitHubCommit? {
        try await commits(path: path, limit: 1).first
    }

    /// The unified-diff patch for `path` between two commits, or nil if GitHub
    /// omitted it (e.g. the file is unchanged or the diff is too large). (Spec C2.)
    func diff(path: String, from base: String, to head: String) async throws -> String? {
        let data = try await get("/repos/\(owner)/\(repo)/compare/\(encode(path: base))...\(encode(path: head))")
        guard let compare = try? JSONDecoder().decode(CompareDTO.self, from: data) else { throw GitHubError.decoding }
        return compare.files?.first { $0.filename == path }?.patch
    }

    // MARK: - Write path (Spec C3)

    /// Shared primitive behind `fileVersion`/`fileData`: fetch a file's Contents API entry
    /// and base64-decode its body. `contentLength` is the API's declared byte size — GitHub
    /// omits `content` above ~1MB, so callers can tell "too large" apart from other failures.
    private func fileBlob(path: String, ref: String) async throws -> (data: Data, sha: String, contentLength: Int?) {
        let data = try await get("/repos/\(owner)/\(repo)/contents/\(encode(path: path))?ref=\(encode(query: ref))")
        guard let c = try? JSONDecoder().decode(Contents.self, from: data) else { throw GitHubError.decoding }
        // Above the Contents API's inline-content limit, GitHub still returns 200 with
        // `size` set but `content` empty — check size explicitly rather than relying on
        // `encoding`, which stays "base64" either way.
        guard c.size <= Self.contentsAPIInlineLimit else { throw GitHubError.contentTooLarge }
        guard c.encoding == "base64" else { throw GitHubError.decoding }
        let cleaned = c.content.replacingOccurrences(of: "\n", with: "")
        guard let decoded = Data(base64Encoded: cleaned) else { throw GitHubError.decoding }
        return (decoded, c.sha, c.size)
    }

    /// GitHub's Contents API omits inline `content` for files roughly above this size.
    private static let contentsAPIInlineLimit = 1_000_000

    /// The current text *and* blob SHA of a file on `branch`. The SHA is required to
    /// commit an update (optimistic concurrency — GitHub rejects a stale SHA).
    func fileVersion(path: String, ref: String) async throws -> (text: String, sha: String) {
        let blob = try await fileBlob(path: path, ref: ref)
        guard let text = String(data: blob.data, encoding: .utf8) else { throw GitHubError.decoding }
        return (text, blob.sha)
    }

    /// Raw bytes of a file at `path`, for non-text content (e.g. images). Throws
    /// `.contentTooLarge` when the file exceeds the Contents API's inline-content limit,
    /// so callers (e.g. `ImageViewerView`) can show a specific message instead of a
    /// generic load failure.
    func fileData(path: String, ref: String) async throws -> Data {
        try await fileBlob(path: path, ref: ref).data
    }

    /// Commit new contents for a file on `branch`. `sha` is the existing file's blob SHA
    /// for an update, or `nil` to create a new file (GitHub creates rather than updates
    /// when `sha` is omitted from the request). Returns the commit's html_url.
    @discardableResult
    func commitFile(path: String, message: String, text: String, sha: String?, branch: String) async throws -> String? {
        var body: [String: Any] = [
            "message": message,
            "content": Data(text.utf8).base64EncodedString(),
            "branch": branch,
        ]
        if let sha { body["sha"] = sha }
        let data = try await send("PUT", "/repos/\(owner)/\(repo)/contents/\(encode(path: path))", body: body)
        return (try? JSONDecoder().decode(WriteResponse.self, from: data))?.commit.html_url
    }

    /// The head commit SHA of `branch`.
    func headSHA(branch: String) async throws -> String {
        let data = try await get("/repos/\(owner)/\(repo)/git/ref/heads/\(encode(path: branch))")
        guard let ref = try? JSONDecoder().decode(RefDTO.self, from: data) else { throw GitHubError.decoding }
        return ref.object.sha
    }

    /// Create a new branch `name` pointing at `fromSHA`.
    func createBranch(name: String, fromSHA: String) async throws {
        _ = try await send("POST", "/repos/\(owner)/\(repo)/git/refs",
                           body: ["ref": "refs/heads/\(name)", "sha": fromSHA])
    }

    /// Open a pull request. Returns the PR's html_url.
    func openPullRequest(title: String, body: String, head: String, base: String) async throws -> String? {
        let data = try await send("POST", "/repos/\(owner)/\(repo)/pulls",
                                  body: ["title": title, "body": body, "head": head, "base": base])
        return (try? JSONDecoder().decode(PullResponse.self, from: data))?.html_url
    }

    // MARK: - Branches (Feature 5)

    /// All branches in the repo (up to 100), sorted by GitHub's default order.
    func branches() async throws -> [String] {
        let data = try await get("/repos/\(owner)/\(repo)/branches?per_page=100")
        guard let dtos = try? JSONDecoder().decode([BranchDTO].self, from: data) else {
            throw GitHubError.decoding
        }
        return dtos.map(\.name)
    }

    // MARK: - Multi-file commits (Feature 4)

    private struct CommitObject: Decodable {
        let tree: TreeRef
        struct TreeRef: Decodable { let sha: String }
    }
    private struct TreeResponse: Decodable { let sha: String }
    private struct CommitResponse: Decodable { let sha: String }

    /// The root tree SHA for a given commit SHA.
    func treeSHA(commitSHA: String) async throws -> String {
        let data = try await get("/repos/\(owner)/\(repo)/git/commits/\(commitSHA)")
        guard let obj = try? JSONDecoder().decode(CommitObject.self, from: data) else {
            throw GitHubError.decoding
        }
        return obj.tree.sha
    }

    private struct RecursiveTree: Decodable {
        struct Node: Decodable { let path: String; let type: String; let sha: String }
        let tree: [Node]
    }

    /// Current blob SHA of every file at `treeSHA`, keyed by path. Used to detect a
    /// concurrent edit before an atomic multi-file commit overwrites it.
    private func blobSHAs(atTreeSHA treeSHA: String) async throws -> [String: String] {
        let data = try await get("/repos/\(owner)/\(repo)/git/trees/\(treeSHA)?recursive=1")
        guard let resp = try? JSONDecoder().decode(RecursiveTree.self, from: data) else {
            throw GitHubError.decoding
        }
        return Dictionary(uniqueKeysWithValues: resp.tree.filter { $0.type == "blob" }.map { ($0.path, $0.sha) })
    }

    /// Atomically commit multiple files via the Git Data API.
    /// Returns the new commit's html_url (constructed from the SHA).
    ///
    /// Each file's `blobSHA` is the blob it was last read at; if the file has since
    /// changed on GitHub (a concurrent edit), this throws `.conflict` before writing
    /// anything, mirroring the single-file Contents API's optimistic concurrency check.
    @discardableResult
    func commitFiles(
        _ files: [(path: String, text: String, blobSHA: String)],
        message: String,
        branch: String
    ) async throws -> String {
        // 1. HEAD commit SHA for the branch
        let baseSHA = try await headSHA(branch: branch)
        // 2. Base tree SHA from the commit
        let baseTreeSHA = try await treeSHA(commitSHA: baseSHA)
        // 2b. Detect concurrent edits: compare each file's current blob SHA against
        // the SHA it was read at. A path missing from the current tree is a new file.
        let currentSHAs = try await blobSHAs(atTreeSHA: baseTreeSHA)
        for file in files {
            if let currentSHA = currentSHAs[file.path], currentSHA != file.blobSHA {
                throw GitHubError.conflict
            }
        }
        // 3. Create new tree
        let treeNodes: [[String: Any]] = files.map { file in
            ["path": file.path, "mode": "100644", "type": "blob", "content": file.text]
        }
        let treeData = try await send(
            "POST", "/repos/\(owner)/\(repo)/git/trees",
            body: ["base_tree": baseTreeSHA, "tree": treeNodes]
        )
        guard let treeResp = try? JSONDecoder().decode(TreeResponse.self, from: treeData) else {
            throw GitHubError.decoding
        }
        // 4. Create commit
        let commitData = try await send(
            "POST", "/repos/\(owner)/\(repo)/git/commits",
            body: ["message": message, "tree": treeResp.sha, "parents": [baseSHA]]
        )
        guard let commitResp = try? JSONDecoder().decode(CommitResponse.self, from: commitData) else {
            throw GitHubError.decoding
        }
        // 5. Advance the branch ref
        _ = try await send(
            "PATCH", "/repos/\(owner)/\(repo)/git/refs/heads/\(encode(path: branch))",
            body: ["sha": commitResp.sha]
        )
        return "https://github.com/\(owner)/\(repo)/commit/\(commitResp.sha)"
    }

    // MARK: - Search (Feature 6)

    /// Search the repo for files whose contents match `query`. Returns up to 30 results
    /// with a matched content fragment. Uses the text-match Accept header on this request only.
    func searchCode(query: String) async throws -> [CodeSearchResult] {
        let q = encode(query: "\(query) repo:\(owner)/\(repo)")
        var req = try request("/search/code?q=\(q)&per_page=30")
        req.setValue("application/vnd.github.text-match+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw GitHubError.badResponse(code) }
        guard let sr = try? JSONDecoder().decode(SearchResponse.self, from: data) else {
            throw GitHubError.decoding
        }
        return sr.items.map {
            CodeSearchResult(path: $0.path, fragment: $0.text_matches?.first?.fragment)
        }
    }
}
