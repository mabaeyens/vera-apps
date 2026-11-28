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
            if showsBreadcrumb, case .file(let url) = source {
                BreadcrumbBar(fileURL: url, rootURL: vm.rootURL)
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
    let rootURL: URL?

    private struct Segment: Identifiable {
        let url: URL
        let name: String
        var id: String { url.path }
    }

    /// True when the file sits inside the opened folder, so segments can reveal tree rows.
    private var isInTree: Bool {
        guard let rootURL else { return false }
        // Resolve symlinks on both sides, as openFile does, so /var vs /private/var
        // spellings of the same location still count as inside the tree.
        return fileURL.resolvingSymlinksInPath().path
            .hasPrefix(rootURL.resolvingSymlinksInPath().path + "/")
    }

    /// Root folder, each folder down to the file, then the file. A standalone file (no
    /// folder open, or outside it) shows its on-disk path instead, home shown as "~".
    private var segments: [Segment] {
        guard let rootURL, isInTree else { return standaloneSegments }
        let rootPath = rootURL.resolvingSymlinksInPath().path
        let filePath = fileURL.resolvingSymlinksInPath().path
        var result = [Segment(url: rootURL, name: rootURL.lastPathComponent)]
        var current = rootURL
        for part in filePath.dropFirst(rootPath.count + 1).split(separator: "/") {
            current = current.appendingPathComponent(String(part))
            result.append(Segment(url: current, name: String(part)))
        }
        return result
    }

    /// No grant for this folder yet: the macOS picker opens there so one click on
    /// "Open This Folder" grants it and makes it the root. No-op on iOS.
    private func openPicker(at folder: URL) {
        #if os(macOS)
        NotificationCenter.default.post(name: .veraOpenPicker, object: folder)
        #endif
    }

    private var standaloneSegments: [Segment] {
        // NSHomeDirectory() is the sandbox container on macOS; use the real home.
        let home = getpwuid(getuid()).flatMap { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        var path = fileURL.standardizedFileURL.path
        var current = URL(fileURLWithPath: "/")
        var result: [Segment] = []
        if path.hasPrefix(home + "/") {
            path = String(path.dropFirst(home.count + 1))
            current = URL(fileURLWithPath: home)
            result.append(Segment(url: current, name: "~"))
        }
        for part in path.split(separator: "/") {
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
                        let isLast = index == segs.count - 1
                        Button {
                            if isInTree || isLast {
                                NotificationCenter.default.post(name: .veraRevealActiveFile, object: seg.url)
                            } else {
                                openPicker(at: seg.url)
                            }
                        } label: {
                            Text(seg.name)
                                .font(.callout)
                                .fontWeight(index == segs.count - 1 ? .medium : .regular)
                                .foregroundStyle(index == segs.count - 1 ? .primary : .secondary)
                                .lineLimit(1)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        #if os(iOS)
                        // iOS can't start its picker in a given folder.
                        .disabled(!isInTree && !isLast)
                        #endif
                        .accessibilityLabel(isLast
                                            ? "Show \(seg.name) in sidebar"
                                            : (isInTree ? "Show folder \(seg.name) in sidebar" : "Open folder \(seg.name)"))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
    }
}
