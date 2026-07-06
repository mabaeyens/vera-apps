import Foundation
import Observation

/// Tracks GitHub files that have unsaved edits across all open document tabs.
/// Injected as an environment object from `VeraApp`; `DocumentView` registers
/// and deregisters entries as files are edited or closed.
@MainActor
@Observable
final class GitHubDraftStore {

    struct Draft: Identifiable {
        let ref: GitHubFileRef
        var text: String
        var blobSHA: String
        var id: String { ref.owner + "/" + ref.repo + "/" + ref.branch + "/" + ref.path }
        var fileName: String { (ref.path as NSString).lastPathComponent }
    }

    private(set) var drafts: [GitHubFileRef: Draft] = [:]

    func register(ref: GitHubFileRef, text: String, blobSHA: String) {
        drafts[ref] = Draft(ref: ref, text: text, blobSHA: blobSHA)
    }

    func deregister(ref: GitHubFileRef) {
        drafts.removeValue(forKey: ref)
    }

    /// All dirty drafts for a specific owner/repo, regardless of branch.
    func repoDrafts(owner: String, repo: String) -> [Draft] {
        drafts.values
            .filter { $0.ref.owner == owner && $0.ref.repo == repo }
            .sorted { $0.ref.path < $1.ref.path }
    }

    /// Deregister a set of paths on a specific branch (after a successful multi-file commit).
    /// Branch-scoped so a commit on one branch never drops a draft for the same path on another.
    func deregisterPaths(_ paths: Set<String>, owner: String, repo: String, branch: String) {
        for key in drafts.keys
        where key.owner == owner && key.repo == repo && key.branch == branch && paths.contains(key.path) {
            drafts.removeValue(forKey: key)
        }
    }
}
