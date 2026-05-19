import Foundation

enum CloudScanner {
    // Shallow scan: returns direct .md files + direct subfolders with empty children.
    // Subfolders are loaded lazily when the user expands them in the sidebar.
    // nonisolated so FileManager work runs on the cooperative thread pool, not the main thread.
    nonisolated static func scan(root: URL) async throws -> [FileNode] {
        try await scanShallow(at: root)
    }

    nonisolated static func scanShallow(at url: URL) async throws -> [FileNode] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .ubiquitousItemDownloadingStatusKey],
            options: [.skipsHiddenFiles]
        )

        var folders: [FileNode] = []
        var files: [FileNode] = []

        for itemURL in contents {
            let resources = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
            if resources.isDirectory == true {
                // Children are empty until the user expands the folder (lazy load).
                folders.append(.folder(
                    id: stableID(for: itemURL),
                    name: itemURL.lastPathComponent,
                    url: itemURL,
                    children: []
                ))
            } else if itemURL.pathExtension.lowercased() == "md" {
                files.append(.file(
                    id: UUID(),
                    name: itemURL.lastPathComponent,
                    url: itemURL,
                    downloadState: downloadState(for: itemURL)
                ))
            }
        }

        let sort: (FileNode, FileNode) -> Bool = { $0.name.localizedCompare($1.name) == .orderedAscending }
        return folders.sorted(by: sort) + files.sorted(by: sort)
    }

    // Generates a deterministic UUID from a folder URL so expand/collapse state
    // is preserved across tree reloads.
    static func stableID(for url: URL) -> UUID {
        let path = url.standardizedFileURL.path
        var b = [UInt8](repeating: 0, count: 16)
        for (i, byte) in path.utf8.enumerated() {
            b[i % 16] ^= byte
            b[(i + 5) % 16] = b[(i + 5) % 16] &+ byte
        }
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
