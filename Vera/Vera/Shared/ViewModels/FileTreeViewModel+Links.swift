import Foundation

/// Navigation for links clicked in the rendered preview.
extension FileTreeViewModel {
    /// Open the document a link points at, in a tab. `.anchor` links are handled by the
    /// preview itself (they only scroll), so they are ignored here.
    func openLink(_ link: DocLink, from source: DocumentSource) {
        Task {
            switch source {
            case .file(let url): await openLocalLink(link, from: url)
            case .gitHub(let ref): openGitHubLink(link, from: ref)
            }
        }
    }

    private func linkLabel(_ link: DocLink) -> String {
        switch link {
        case .relative(let path, _): return (path as NSString).lastPathComponent
        case .wiki(let name, _): return name
        case .anchor(let fragment): return fragment
        }
    }

    // MARK: Local files

    private func openLocalLink(_ link: DocLink, from url: URL) async {
        if case .anchor = link { return }
        let failure = FileOpenError.linkNotFound(linkLabel(link))

        // Links resolve inside the opened folder only. A standalone file has no folder,
        // and under the sandbox its siblings aren't readable anyway.
        guard let root = rootURL?.resolvingSymlinksInPath() else { fileOpenError = failure; return }
        let current = url.resolvingSymlinksInPath()
        guard current.path.hasPrefix(root.path + "/") else { fileOpenError = failure; return }

        let target: URL?
        let fragment: String?
        switch link {
        case .relative(let path, let f):
            fragment = f
            let isRootRelative = path.hasPrefix("/")
            let base = isRootRelative ? root : current.deletingLastPathComponent()
            let relative = isRootRelative ? String(path.dropFirst()) : path
            let candidate = URL(fileURLWithPath: relative, isDirectory: false, relativeTo: base)
                .standardizedFileURL.resolvingSymlinksInPath()
            target = Self.existingFile(candidate)
        case .wiki(let name, let f):
            fragment = f
            let files = await FileIndex.build(root: root)
            target = FileIndex.resolveWiki(name: name, in: files, near: current, root: root)
        case .anchor:
            return
        }

        // Resolve both sides: an enumerator can hand back `/private/tmp/...` for a root
        // opened as `/tmp/...`, and a plain prefix check would then reject a real match.
        guard let target = target?.resolvingSymlinksInPath(),
              target.path.hasPrefix(root.path + "/") else { fileOpenError = failure; return }
        openFileInNewTab(target)
        if let fragment, let tab = tabs.first(where: { $0.source == .file(target) }) {
            tab.editor.pendingAnchor = fragment
        }
    }

    /// The file at `candidate`, trying a `.md` extension when none was written.
    private static func existingFile(_ candidate: URL) -> URL? {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDir), !isDir.boolValue {
            return candidate
        }
        guard candidate.pathExtension.isEmpty else { return nil }
        let withMarkdown = candidate.appendingPathExtension("md")
        return FileManager.default.fileExists(atPath: withMarkdown.path) ? withMarkdown : nil
    }

    // MARK: GitHub files

    private func openGitHubLink(_ link: DocLink, from ref: GitHubFileRef) {
        guard case .relative(let path, let fragment) = link else {
            // No file index for a remote repo, so `[[wikilinks]]` can't be resolved.
            if case .wiki = link { fileOpenError = .linkNotFound(linkLabel(link)) }
            return
        }
        let directory = (ref.path as NSString).deletingLastPathComponent
        let joined = path.hasPrefix("/")
            ? String(path.dropFirst())
            : (directory.isEmpty ? path : directory + "/" + path)

        // Collapse "." and ".." without ever stepping above the repo root.
        var parts: [String] = []
        for part in joined.split(separator: "/", omittingEmptySubsequences: true) {
            if part == "." { continue }
            if part == ".." {
                guard !parts.isEmpty else { fileOpenError = .linkNotFound(linkLabel(link)); return }
                parts.removeLast()
            } else {
                parts.append(String(part))
            }
        }
        var resolved = parts.joined(separator: "/")
        guard !resolved.isEmpty else { fileOpenError = .linkNotFound(linkLabel(link)); return }
        if (resolved as NSString).pathExtension.isEmpty { resolved += ".md" }

        let source = DocumentSource.gitHub(GitHubFileRef(
            owner: ref.owner, repo: ref.repo, path: resolved, branch: ref.branch
        ))
        openInNewTab(source)
        if let fragment, let tab = tabs.first(where: { $0.source == source }) {
            tab.editor.pendingAnchor = fragment
        }
    }
}
