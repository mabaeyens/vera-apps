import Foundation

@MainActor
enum DocumentStore {
    static func read(_ url: URL) throws -> String {
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
        return content
    }

    static func write(_ url: URL, content: String) throws {
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
    }
}
