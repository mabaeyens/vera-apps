import Foundation

/// Where a document's content comes from. Lets the editor (`EditorViewModel` /
/// `DocumentView`) work identically against a local/iCloud file or a GitHub repo file.
enum DocumentSource: Hashable, Identifiable {
    case file(URL)
    case gitHub(GitHubFileRef)

    var id: String {
        switch self {
        case .file(let url): return "file:\(url.absoluteString)"
        case .gitHub(let ref): return "gh:\(ref.owner)/\(ref.repo)@\(ref.branch)/\(ref.path)"
        }
    }

    var displayName: String {
        switch self {
        case .file(let url): return url.deletingPathExtension().lastPathComponent
        case .gitHub(let ref): return (ref.path as NSString).lastPathComponent
        }
    }

    var isGitHub: Bool {
        if case .gitHub = self { return true }
        return false
    }
}

/// A file inside a GitHub repo, enough to read it and commit back to it. The token is
/// not stored here — it is read from the Keychain (`CredentialStore`) when needed.
struct GitHubFileRef: Hashable {
    let owner: String
    let repo: String
    let path: String
    let branch: String
}
