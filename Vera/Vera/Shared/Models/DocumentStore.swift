import Foundation

// NSFileCoordinator.coordinate() is synchronous and blocks the calling thread.
// Running it on the main thread after a long background causes the iCloud daemon
// to reconnect, which can freeze the UI for several seconds. Both methods use
// Task.detached so the coordinator work happens off the main thread.
enum DocumentStore {
    static func read(_ url: URL) async throws -> String {
        try await readDecoded(url).text
    }

    /// Decode raw bytes: UTF-8 first, then UTF-16 (with BOM), then Latin-1 so a legacy
    /// config still opens. Anything with NUL bytes that isn't UTF-16 is binary and fails.
    nonisolated static func decode(_ data: Data) -> (text: String, encoding: String.Encoding)? {
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]),
           let text = String(data: data, encoding: .utf16) { return (text, .utf16) }
        if let text = String(data: data, encoding: .utf8) { return (text, .utf8) }
        if data.contains(0) { return nil }
        if let text = String(data: data, encoding: .isoLatin1) { return (text, .isoLatin1) }
        return nil
    }

    /// Like `read`, but also reports the encoding so a save can write the file back the
    /// way it came (a Latin-1 file must not silently become UTF-8).
    static func readDecoded(_ url: URL) async throws -> (text: String, encoding: String.Encoding) {
        try await Task.detached(priority: .userInitiated) {
            var content: (text: String, encoding: String.Encoding)?
            var readError: Error?
            var coordError: NSError?

            let coordinator = NSFileCoordinator()
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { coordURL in
                do {
                    let data = try Data(contentsOf: coordURL)
                    guard let decoded = decode(data) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
                    content = decoded
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
    /// Above this size a CSV/TSV opens as a read-only preview instead of loading whole.
    static let tablePreviewThreshold = 1_000_000
    static let tablePreviewRows = 100

    /// First `tablePreviewRows` lines of a large CSV/TSV, or nil when the file isn't one or
    /// is small enough to open normally. Reads only the head of the file.
    static func readTablePreview(_ url: URL) async -> String? {
        let ext = url.pathExtension.lowercased()
        guard ext == "csv" || ext == "tsv" else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> String? in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            guard size > tablePreviewThreshold,
                  let handle = try? FileHandle(forReadingFrom: url),
                  let data = try? handle.read(upToCount: 512_000) else { return nil }
            try? handle.close()
            let text = String(decoding: data, as: UTF8.self)
            let rows = text.split(separator: "\n", maxSplits: tablePreviewRows, omittingEmptySubsequences: false)
                .prefix(tablePreviewRows)
            return rows.joined(separator: "\n")
        }.value
    }

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

    static func write(_ url: URL, content: String, encoding: String.Encoding = .utf8) async throws {
        try await Task.detached(priority: .userInitiated) {
            var writeError: Error?
            var coordError: NSError?

            let coordinator = NSFileCoordinator()
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { coordURL in
                do {
                    // Latin-1 can't hold every character; widen to UTF-8 rather than fail the save.
                    let enc = content.canBeConverted(to: encoding) ? encoding : .utf8
                    try content.write(to: coordURL, atomically: true, encoding: enc)
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
