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

    var errorDescription: String? {
        switch self {
        case .badResponse(let code):
            if code == 401 { return "GitHub rejected the token. Check it has access to this repo." }
            if code == 404 { return "Repository or path not found." }
            return "GitHub returned an error (\(code))."
        case .notMarkdown: return "That file isn't Markdown."
        case .decoding: return "Couldn't read GitHub's response."
        case .conflict: return "The file changed on GitHub since you opened it."
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
    private struct Contents: Decodable { let content: String; let encoding: String; let sha: String }
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

    /// All Markdown files in the repo (recursive), sorted by path.
    func markdownFiles(branch: String) async throws -> [GitHubItem] {
        let data = try await get("/repos/\(owner)/\(repo)/git/trees/\(encode(path: branch))?recursive=1")
        guard let tree = try? JSONDecoder().decode(Tree.self, from: data) else { throw GitHubError.decoding }
        return tree.tree
            .filter { $0.type == "blob" && ($0.path.hasSuffix(".md") || $0.path.hasSuffix(".markdown")) }
            .map { GitHubItem(path: $0.path) }
            .sorted { $0.path.localizedCompare($1.path) == .orderedAscending }
    }

    /// Raw Markdown text of a file at `path`.
    func fileContents(path: String) async throws -> String {
        let encodedPath = path
            .split(separator: "/")
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        let data = try await get("/repos/\(owner)/\(repo)/contents/\(encodedPath)")
        guard let contents = try? JSONDecoder().decode(Contents.self, from: data),
              contents.encoding == "base64" else { throw GitHubError.decoding }
        let cleaned = contents.content.replacingOccurrences(of: "\n", with: "")
        guard let decoded = Data(base64Encoded: cleaned),
              let text = String(data: decoded, encoding: .utf8) else { throw GitHubError.decoding }
        return text
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

    /// The current text *and* blob SHA of a file on `branch`. The SHA is required to
    /// commit an update (optimistic concurrency — GitHub rejects a stale SHA).
    func fileVersion(path: String, ref: String) async throws -> (text: String, sha: String) {
        let data = try await get("/repos/\(owner)/\(repo)/contents/\(encode(path: path))?ref=\(encode(query: ref))")
        guard let c = try? JSONDecoder().decode(Contents.self, from: data),
              c.encoding == "base64" else { throw GitHubError.decoding }
        let cleaned = c.content.replacingOccurrences(of: "\n", with: "")
        guard let decoded = Data(base64Encoded: cleaned),
              let text = String(data: decoded, encoding: .utf8) else { throw GitHubError.decoding }
        return (text, c.sha)
    }

    /// Commit new contents for a file on `branch`. Returns the commit's html_url.
    @discardableResult
    func commitFile(path: String, message: String, text: String, sha: String, branch: String) async throws -> String? {
        let body: [String: Any] = [
            "message": message,
            "content": Data(text.utf8).base64EncodedString(),
            "sha": sha,
            "branch": branch,
        ]
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
