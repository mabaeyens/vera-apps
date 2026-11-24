import Foundation
import CryptoKit

enum CloudScanner {
    // Shallow scan: returns every direct file Vera can open (text, code, images; binaries are skipped) + direct subfolders with empty children.
    // Subfolders are loaded lazily when the user expands them in the sidebar.
    // nonisolated so FileManager work runs on the cooperative thread pool, not the main thread.
    nonisolated static func scan(root: URL) async throws -> [FileNode] {
        try await scanShallow(at: root)
    }

    nonisolated static func scanShallow(at url: URL) async throws -> [FileNode] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .ubiquitousItemDownloadingStatusKey, .contentModificationDateKey],
            options: Defaults.showHiddenFiles ? [] : [.skipsHiddenFiles]
        )

        struct Dated {
            let node: FileNode
            let date: Date
        }
        var folders: [Dated] = []
        var files: [Dated] = []

        for itemURL in contents {
            // Finder litter, never worth a row even with hidden files shown.
            if itemURL.lastPathComponent == ".DS_Store" { continue }
            // Skip an individual unreadable item rather than aborting the whole scan
            // (which would blank the sidebar over one bad file).
            guard let resources = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]) else { continue }
            let modDate = resources.contentModificationDate ?? .distantPast
            if resources.isDirectory == true {
                folders.append(Dated(
                    node: .folder(id: stableID(for: itemURL), name: itemURL.lastPathComponent, url: itemURL, children: []),
                    date: modDate
                ))
            } else {
                // Only list files Vera can open; folders always stay so any place is browsable.
                if FileKind.classify(path: itemURL.path) == .binary { continue }
                files.append(Dated(
                    // Stable per path, like folders: a fresh UUID per scan made every
                    // refresh look like a brand-new row to the sidebar list.
                    node: .file(id: stableID(for: itemURL), name: itemURL.lastPathComponent, url: itemURL, downloadState: downloadState(for: itemURL)),
                    date: modDate
                ))
            }
        }

        let byDateDesc: (Dated, Dated) -> Bool = { $0.date > $1.date }
        return files.sorted(by: byDateDesc).map(\.node) + folders.sorted(by: byDateDesc).map(\.node)
    }

    // Generates a deterministic UUID from a URL so expand/collapse state is preserved
    // across tree reloads, and rows keep their identity. The first 16 bytes of a SHA-256:
    // the XOR-fold this replaced collided for paths that differ only by swapping
    // characters 16 apart, and with ids now covering files a collision would show one row twice.
    nonisolated static func stableID(for url: URL) -> UUID {
        let path = url.standardizedFileURL.path
        var b = Array(SHA256.hash(data: Data(path.utf8)).prefix(16))
        b[6] = (b[6] & 0x0F) | 0x40
        b[8] = (b[8] & 0x3F) | 0x80
        return UUID(uuid: (b[0],b[1],b[2],b[3],b[4],b[5],b[6],b[7],b[8],b[9],b[10],b[11],b[12],b[13],b[14],b[15]))
    }

    nonisolated private static func downloadState(for url: URL) -> DownloadState {
        guard
            let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
            let status = values.ubiquitousItemDownloadingStatus
        else { return .local }

        switch status {
        case .notDownloaded: return .cloud
        default: return .local
        }
    }
}
