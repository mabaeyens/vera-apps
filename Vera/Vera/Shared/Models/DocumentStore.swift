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

            if let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url), !conflicts.isEmpty {
                conflicts.forEach { $0.isResolved = true }
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

            try? NSFileVersion.removeOtherVersionsOfItem(at: url)
        }.value
    }
}
