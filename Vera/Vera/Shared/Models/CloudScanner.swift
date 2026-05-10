import Foundation

enum CloudScanner {
    static func iCloudRoot() async -> URL? {
        await Task.detached(priority: .userInitiated) {
            FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.mira.vera")
                .map { $0.appendingPathComponent("Documents") }
        }.value
    }

    static func scan(root: URL) async throws -> [FileNode] {
        try await Task.detached(priority: .userInitiated) {
            try Self.scanDirectory(at: root)
        }.value
    }

    private static func scanDirectory(at url: URL) throws -> [FileNode] {
        let fm = FileManager.default

        // Ensure the directory is downloaded before reading
        try? fm.startDownloadingUbiquitousItem(at: url)

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
                let children = (try? scanDirectory(at: itemURL)) ?? []
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
