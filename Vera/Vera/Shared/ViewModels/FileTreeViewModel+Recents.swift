import Foundation

/// Recently opened files, most recent first, for the quick switcher's empty state.
/// Stored as plain paths: it is a convenience list, not a grant of access, so a file that
/// has since moved or become unreadable is just filtered out when shown.
extension FileTreeViewModel {
    private static let recentLimit = 20

    static func noteRecent(_ url: URL) {
        var paths = UserDefaults.standard.stringArray(forKey: Defaults.Key.recentFiles) ?? []
        paths.removeAll { $0 == url.path }
        paths.insert(url.path, at: 0)
        if paths.count > recentLimit { paths.removeLast(paths.count - recentLimit) }
        UserDefaults.standard.set(paths, forKey: Defaults.Key.recentFiles)
    }

    /// Recent files that still exist and sit inside the opened folder.
    func recentFiles() -> [URL] {
        guard let root = rootURL else { return [] }
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return (UserDefaults.standard.stringArray(forKey: Defaults.Key.recentFiles) ?? [])
            .filter { $0.hasPrefix(prefix) && FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }
}
