import Foundation

// NSFileCoordinator.coordinate() is synchronous and blocks the calling thread.
// Running it on the main thread after a long background causes the iCloud daemon
// to reconnect, which can freeze the UI for several seconds. Both methods use
// Task.detached so the coordinator work happens off the main thread.
enum DocumentStore {
    static func read(_ url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            var content: String?
            var readError: Error?
            var coordError: NSError?

            let coordinator = NSFileCoordinator()
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { coordURL in
                do {
                    content = try String(contentsOf: coordURL, encoding: .utf8)
                } catch {
                    readError = error
                }
            }

            if let coordError { throw coordError }
            if let readError { throw readError }
            guard let content else { throw CocoaError(.fileReadUnknown) }

            if preserveConflicts(at: url) {
                try? NSFileVersion.removeOtherVersionsOfItem(at: url)
            }

            return content
        }.value
    }

    /// Byte-level read for non-text files (e.g. images). Mirrors `read(_:)` — same
    /// coordinator pattern, off the main thread — but returns raw `Data`.
    static func readData(_ url: URL) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            var content: Data?
            var readError: Error?
            var coordError: NSError?

            let coordinator = NSFileCoordinator()
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { coordURL in
                do {
                    content = try Data(contentsOf: coordURL)
                } catch {
                    readError = error
                }
            }

            if let coordError { throw coordError }
            if let readError { throw readError }
            guard let content else { throw CocoaError(.fileReadUnknown) }
            return content
        }.value
    }

    static func write(_ url: URL, content: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            var writeError: Error?
            var coordError: NSError?

            let coordinator = NSFileCoordinator()
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { coordURL in
                do {
                    try content.write(to: coordURL, atomically: true, encoding: .utf8)
                } catch {
                    writeError = error
                }
            }

            if let coordError { throw coordError }
            if let writeError { throw writeError }

            if preserveConflicts(at: url) {
                try? NSFileVersion.removeOtherVersionsOfItem(at: url)
            }
        }.value
    }

    /// Copy every unresolved iCloud conflict version next to the file as
    /// `<name> (conflict <device> <date>).<ext>` and mark it resolved. Returns true when
    /// it is safe to discard the other versions: there were no conflicts, or every one
    /// was saved. If a copy fails (for example a sandboxed single file with no write
    /// access to its folder) the conflicts are left in place rather than deleted, which
    /// is what used to happen silently.
    private static func preserveConflicts(at url: URL) -> Bool {
        guard let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url),
              !conflicts.isEmpty else { return true }

        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd HHmm"

        var allSaved = true
        for version in conflicts {
            let device = (version.localizedNameOfSavingComputer ?? "other device")
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let when = version.modificationDate.map(stamp.string(from:)) ?? "unknown date"
            let stem = "\(base) (conflict \(device) \(when))"

            var destination = dir.appendingPathComponent(ext.isEmpty ? stem : "\(stem).\(ext)")
            var n = 2
            while fm.fileExists(atPath: destination.path) {
                let numbered = "\(stem) \(n)"
                destination = dir.appendingPathComponent(ext.isEmpty ? numbered : "\(numbered).\(ext)")
                n += 1
            }
            do {
                try fm.copyItem(at: version.url, to: destination)
                version.isResolved = true
            } catch {
                allSaved = false
            }
        }
        return allSaved
    }
}
