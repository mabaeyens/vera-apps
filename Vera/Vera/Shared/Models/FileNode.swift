import Foundation

enum DownloadState: Sendable {
    case local, downloading, cloud
}

enum FileNode: Identifiable, Sendable {
    case file(id: UUID, name: String, url: URL, downloadState: DownloadState)
    case folder(id: UUID, name: String, url: URL, children: [FileNode])

    var id: UUID {
        switch self {
        case .file(let id, _, _, _): return id
        case .folder(let id, _, _, _): return id
        }
    }

    var name: String {
        switch self {
        case .file(_, let name, _, _): return name
        case .folder(_, let name, _, _): return name
        }
    }

    // nil for files so List(children:) knows to stop recursing
    var children: [FileNode]? {
        if case .folder(_, _, _, let c) = self { return c.isEmpty ? nil : c }
        return nil
    }
}
