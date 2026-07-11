import Foundation

/// Keeps a local file tree in sync with a connected GitHub repository, polling
/// for upstream changes and reconciling them against any unsaved local edits.
actor RepoSyncEngine {
    enum SyncState: Equatable {
        case idle
        case syncing(progress: Double)
        case conflict(path: String)
        case failed(String)
    }

    private(set) var state: SyncState = .idle
    private let client: GitHubClient
    private var lastKnownSHA: [String: String] = [:]

    init(client: GitHubClient) {
        self.client = client
    }

    func sync(branch: String) async throws {
        state = .syncing(progress: 0)
        let tree = try await client.documentFiles(branch: branch)

        for (index, item) in tree.enumerated() {
            let progress = Double(index) / Double(max(tree.count, 1))
            state = .syncing(progress: progress)

            guard let remoteSHA = try? await client.blobSHA(path: item.path, ref: branch) else {
                continue
            }

            if let localSHA = lastKnownSHA[item.path], localSHA != remoteSHA {
                state = .conflict(path: item.path)
                return
            }
            lastKnownSHA[item.path] = remoteSHA
        }

        state = .idle
    }

    func markResolved(_ path: String, sha: String) {
        lastKnownSHA[path] = sha
        if case .conflict(let conflictedPath) = state, conflictedPath == path {
            state = .idle
        }
    }
}
