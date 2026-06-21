import Foundation

/// A Markdown file inside a GitHub repository.
struct GitHubItem: Identifiable, Hashable {
    let path: String
    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
}

enum GitHubError: LocalizedError {
    case badResponse(Int)
    case notMarkdown
    case decoding

    var errorDescription: String? {
        switch self {
        case .badResponse(let code):
            if code == 401 { return "GitHub rejected the token. Check it has access to this repo." }
            if code == 404 { return "Repository or path not found." }
            return "GitHub returned an error (\(code))."
        case .notMarkdown: return "That file isn't Markdown."
        case .decoding: return "Couldn't read GitHub's response."
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

    private func get(_ path: String) async throws -> Data {
        guard let url = URL(string: Self.apiBase + path) else { throw GitHubError.badResponse(0) }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw GitHubError.badResponse(code) }
        return data
    }

    private struct RepoMeta: Decodable { let default_branch: String }
    private struct Tree: Decodable {
        struct Node: Decodable { let path: String; let type: String }
        let tree: [Node]
    }
    private struct Contents: Decodable { let content: String; let encoding: String }

    func defaultBranch() async throws -> String {
        let data = try await get("/repos/\(owner)/\(repo)")
        guard let meta = try? JSONDecoder().decode(RepoMeta.self, from: data) else { throw GitHubError.decoding }
        return meta.default_branch
    }

    /// All Markdown files in the repo (recursive), sorted by path.
    func markdownFiles(branch: String) async throws -> [GitHubItem] {
        let data = try await get("/repos/\(owner)/\(repo)/git/trees/\(branch)?recursive=1")
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
}
