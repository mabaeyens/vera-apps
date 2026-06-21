import Foundation

/// A GitHub repository the user has connected. Owner/repo only — non-secret, so it is
/// safe to sync across devices. The PAT is **not** stored here; it lives in the Keychain
/// (`CredentialStore`) and never leaves the device.
struct SavedRepo: Codable, Identifiable, Hashable {
    let owner: String
    let repo: String
    var id: String { "\(owner)/\(repo)" }
    var displayName: String { "\(owner)/\(repo)" }
}

/// The list of connected repos, stored in iCloud key-value storage so it syncs across
/// the user's devices. On a new device the repos appear, but the token must be entered
/// once there (it is device-local by design — see `CredentialStore`).
enum RepoListStore {
    private static let key = "github.savedRepos"
    private static var store: NSUbiquitousKeyValueStore { .default }

    /// Posted by iCloud when another device changes the list.
    static let didChangeExternally = NSUbiquitousKeyValueStore.didChangeExternallyNotification
    /// Posted on this device after a local add/remove (the iCloud notification only
    /// fires for *external* changes). Views observe both to stay current.
    static let didChange = Notification.Name("com.mab.vera.reposChanged")

    static func all() -> [SavedRepo] {
        guard let data = store.data(forKey: key),
              let repos = try? JSONDecoder().decode([SavedRepo].self, from: data) else { return [] }
        return repos.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    static func add(_ repo: SavedRepo) {
        var repos = all()
        guard !repos.contains(repo) else { return }
        repos.append(repo)
        save(repos)
    }

    static func remove(_ repo: SavedRepo) {
        save(all().filter { $0 != repo })
    }

    /// Pull the latest values from iCloud. Call once at launch so external changes that
    /// arrived while the app was closed are reflected.
    static func startSyncing() {
        store.synchronize()
    }

    private static func save(_ repos: [SavedRepo]) {
        guard let data = try? JSONEncoder().encode(repos) else { return }
        store.set(data, forKey: key)
        store.synchronize()
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}
