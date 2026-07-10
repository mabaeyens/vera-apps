import Foundation

/// A node in a GitHub repo's Markdown tree (folders + .md leaves), built from the flat
/// recursive path list returned by `GitHubClient.documentFiles`. Files carry a
/// `GitHubFileRef` so they open in the shared editor.
struct RepoTreeNode: Identifiable {
    let id: String          // repo-relative path (unique within the repo)
    let name: String
    let isFolder: Bool
    let ref: GitHubFileRef? // non-nil for files
    var children: [RepoTreeNode]
}

enum RepoTree {
    /// Build a nested folder/file tree from a repo's flat Markdown path list.
    static func build(from items: [GitHubItem], owner: String, repo: String, branch: String) -> [RepoTreeNode] {
        final class Builder {
            var folders: [String: Builder] = [:]
            var files: [(name: String, path: String)] = []
        }
        let root = Builder()
        for item in items {
            let comps = item.path.split(separator: "/").map(String.init)
            guard !comps.isEmpty, let leaf = comps.last else { continue }
            var node = root
            for comp in comps.dropLast() {
                let child = node.folders[comp] ?? Builder()
                node.folders[comp] = child
                node = child
            }
            node.files.append((name: leaf, path: item.path))
        }

        func convert(_ b: Builder, prefix: String) -> [RepoTreeNode] {
            var result: [RepoTreeNode] = []
            for name in b.folders.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
                guard let child = b.folders[name] else { continue }
                let childPrefix = prefix.isEmpty ? name : prefix + "/" + name
                result.append(RepoTreeNode(
                    id: childPrefix, name: name, isFolder: true, ref: nil,
                    children: convert(child, prefix: childPrefix)
                ))
            }
            for file in b.files.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
                result.append(RepoTreeNode(
                    id: file.path, name: file.name, isFolder: false,
                    ref: GitHubFileRef(owner: owner, repo: repo, path: file.path, branch: branch),
                    children: []
                ))
            }
            return result
        }
        return convert(root, prefix: "")
    }
}

/// Loads and caches each saved repo's Markdown tree on demand (one API call per repo).
@MainActor
@Observable
final class RepoBrowser {
    enum LoadState {
        case idle, loading
        case loaded([RepoTreeNode])
        case failed(String)
    }

    private(set) var states: [String: LoadState] = [:]

    func state(for repo: SavedRepo) -> LoadState { states[repo.id] ?? .idle }

    func loadIfNeeded(_ repo: SavedRepo) async {
        if case .loaded = state(for: repo) { return }
        if case .loading = state(for: repo) { return }
        guard let token = CredentialStore.load() else { return }
        states[repo.id] = .loading
        let client = GitHubClient(owner: repo.owner, repo: repo.repo, token: token)
        do {
            let branch = try await client.defaultBranch()
            let items = try await client.documentFiles(branch: branch)
            states[repo.id] = .loaded(RepoTree.build(from: items, owner: repo.owner, repo: repo.repo, branch: branch))
        } catch {
            states[repo.id] = .failed(error.localizedDescription)
        }
    }

    /// Drop a repo's cached tree (e.g. after it's removed).
    func forget(_ repo: SavedRepo) { states[repo.id] = nil }
}
