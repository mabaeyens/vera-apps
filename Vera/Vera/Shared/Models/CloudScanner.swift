import Foundation

enum CloudScanner {
    static func scan(root: URL) async throws -> [FileNode] {
        let fm = FileManager()
        return try await Task.detached(priority: .userInitiated) {
            try Self.scanDirectory(at: root, fm: fm)
        }.value
    }

    private static func scanDirectory(at url: URL, fm: FileManager) throws -> [FileNode] {

        let contents = try fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .ubiquitousItemDownloadingStatusKey],
            options: [.skipsHiddenFiles]
        )

        var folders: [FileNode] = []
        var files: [FileNode] = []

        for itemURL in contents {
            let resources = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
            if resources.isDirectory == true {
                let children = (try? scanDirectory(at: itemURL, fm: fm)) ?? []
                if !children.isEmpty {
                    folders.append(.folder(id: UUID(), name: itemURL.lastPathComponent, children: children))
                }
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

    private static func downloadState(for url: URL) -> DownloadState {
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
