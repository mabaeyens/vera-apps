import SwiftUI

/// Routes a document source to the right viewer: an image viewer for image files,
/// the editor for everything else. Local files get a breadcrumb bar on top.
struct DocumentOrImageView: View {
    @Environment(FileTreeViewModel.self) private var vm
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    let source: DocumentSource
    /// Owned by the tab, not by `DocumentView`, so it outlives the view being rebuilt on
    /// every tab switch. Unused for images, which have no editor.
    let editor: EditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            if showsBreadcrumb, case .file(let url) = source, let root = vm.rootURL {
                BreadcrumbBar(fileURL: url, rootURL: root)
                Divider()
            }
            if FileKind.classify(path: source.path) == .image {
                ImageViewerView(source: source)
            } else {
                DocumentView(source: source, viewModel: editor)
            }
        }
    }

    /// On iPhone the sidebar is a separate screen behind the back button, so there is no
    /// tree beside the editor for a breadcrumb click to navigate.
    private var showsBreadcrumb: Bool {
        #if os(iOS)
        return sizeClass == .regular
        #else
        return true
        #endif
    }
}

/// Path of the open file relative to the opened folder. Clicking a folder segment
/// reveals it in the sidebar tree (expanding the folders above it); the last segment
/// reveals the file itself.
private struct BreadcrumbBar: View {
    let fileURL: URL
    let rootURL: URL

    private struct Segment: Identifiable {
        let url: URL
        let name: String
        var id: String { url.path }
    }

    /// Root folder, each folder down to the file, then the file. Empty when the file
    /// is outside the opened folder (standalone files have no tree position).
    private var segments: [Segment] {
        let rootPath = rootURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath + "/") else { return [] }
        var result = [Segment(url: rootURL, name: rootURL.lastPathComponent)]
        var current = rootURL
        for part in filePath.dropFirst(rootPath.count + 1).split(separator: "/") {
            current = current.appendingPathComponent(String(part))
            result.append(Segment(url: current, name: String(part)))
        }
        return result
    }

    var body: some View {
        let segs = segments
        if !segs.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(segs.enumerated()), id: \.element.id) { index, seg in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        Button {
                            NotificationCenter.default.post(name: .veraRevealActiveFile, object: seg.url)
                        } label: {
                            Text(seg.name)
                                .font(.callout)
                                .fontWeight(index == segs.count - 1 ? .medium : .regular)
                                .foregroundStyle(index == segs.count - 1 ? .primary : .secondary)
                                .lineLimit(1)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(index == segs.count - 1
                                            ? "Show \(seg.name) in sidebar"
                                            : "Show folder \(seg.name) in sidebar")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
    }
}
