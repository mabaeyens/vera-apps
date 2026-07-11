import Foundation

/// Session-lifetime, in-memory cache of GitHub file content, so reopening a file already
/// viewed this session (e.g. tab close then re-tap in the tree) doesn't re-hit the
/// Contents API. Keyed by `GitHubFileRef` (owner/repo/branch/path), which is exactly the
/// scope a fetched blob is valid for.
@MainActor
enum GitHubFileCache {
    private static var entries: [GitHubFileRef: (text: String, sha: String)] = [:]

    static func lookup(_ ref: GitHubFileRef) -> (text: String, sha: String)? {
        entries[ref]
    }

    static func store(_ ref: GitHubFileRef, text: String, sha: String) {
        entries[ref] = (text, sha)
    }

    /// Drop a stale entry, e.g. after a successful commit changes the file's content/SHA.
    static func invalidate(_ ref: GitHubFileRef) {
        entries.removeValue(forKey: ref)
    }
}
