import Foundation

enum RenameError: LocalizedError {
    case emptyName
    case invalidCharacters
    case alreadyExists(String)
    case notDownloaded
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .emptyName: return "Enter a name."
        case .invalidCharacters: return "A file name can't contain / or : and can't start with a dot."
        case .alreadyExists(let name): return "A file named \"\(name)\" already exists here."
        case .notDownloaded: return "Download this file from iCloud before renaming it."
        case .failed(let reason): return reason
        }
    }
}

extension FileTreeViewModel {
    /// The name to rename to: what was typed, keeping the old extension if none was given.
    static func resolvedName(typed: String, original: URL) -> String {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        let ext = original.pathExtension
        if !ext.isEmpty, (trimmed as NSString).pathExtension.isEmpty { return trimmed + "." + ext }
        return trimmed
    }

    /// Rename a file in place. Open tabs follow it, unsaved edits are written first, and
    /// the sidebar rescans. Refuses to overwrite and to rename an undownloaded iCloud item.
    func renameFile(at url: URL, to typed: String) async throws {
        let name = Self.resolvedName(typed: typed, original: url)
        guard !name.isEmpty else { throw RenameError.emptyName }
        guard !name.contains("/"), !name.contains(":"), !name.hasPrefix(".") else {
            throw RenameError.invalidCharacters
        }
        guard name != url.lastPathComponent else { return }

        let destination = url.deletingLastPathComponent().appendingPathComponent(name)
        // Case-only renames (`a.md` to `A.md`) are legal on a case-insensitive volume,
        // where the destination "exists" because it is the same file.
        let isCaseOnly = destination.path.lowercased() == url.path.lowercased()
        if FileManager.default.fileExists(atPath: destination.path), !isCaseOnly {
            throw RenameError.alreadyExists(name)
        }
        if let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            .ubiquitousItemDownloadingStatus, status == .notDownloaded {
            throw RenameError.notDownloaded
        }

        // Anything still inside the autosave debounce goes to the old path first.
        for tab in tabs where tab.source == .file(url) { await tab.editor.flushPendingSave() }

        try await Task.detached(priority: .userInitiated) {
            var coordError: NSError?
            var moveError: Error?
            NSFileCoordinator().coordinate(
                writingItemAt: url, options: .forMoving,
                writingItemAt: destination, options: .forReplacing,
                error: &coordError
            ) { from, to in
                do { try FileManager.default.moveItem(at: from, to: to) } catch { moveError = error }
            }
            if let coordError { throw RenameError.failed(coordError.localizedDescription) }
            if let moveError { throw RenameError.failed(moveError.localizedDescription) }
        }.value

        followRename(from: url, to: destination)
        await load()
    }

    /// Re-point everything that remembered the old URL.
    private func followRename(from old: URL, to new: URL) {
        // Pinned, recents.
        let defaults = UserDefaults.standard
        for key in [Defaults.Key.pinnedFiles, Defaults.Key.recentFiles] {
            if var paths = defaults.stringArray(forKey: key), let i = paths.firstIndex(of: old.path) {
                paths[i] = new.path
                defaults.set(paths, forKey: key)
            }
        }
        moveAccessGrant(from: old, to: new)

        // Standalone list.
        standaloneFiles = standaloneFiles.map { node in
            if case .file(let id, _, let u, let state) = node, u == old {
                return .file(id: id, name: new.deletingPathExtension().lastPathComponent, url: new, downloadState: state)
            }
            return node
        }

        // Open tabs. An editor's source is immutable, so the tab gets a fresh editor; its
        // text was flushed above and reloads from the new path on display.
        let newSource = DocumentSource.file(new)
        for index in tabs.indices where tabs[index].source == .file(old) {
            let wasActive = tabs[index].id == activeTabID
            let replacement = TabEntry(source: newSource)
            replaceTabIdentity(tabs[index].id, with: replacement.id)
            tabs[index] = replacement
            if wasActive {
                activeTabID = replacement.id
                selectedSource = newSource
            }
        }
    }
}
