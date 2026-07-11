import SwiftUI

/// The Markdown mark (by dcurtis, CC0 — credited in About), template-rendered so it
/// tints like an SF Symbol. Used for Markdown file rows in the sidebar.
struct MarkdownFileIcon: View {
    var body: some View {
        Image("MarkdownMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 14)
    }
}

/// File-row icon that picks the right glyph for the file — the Markdown mark for `.md`,
/// an SF Symbol for the other editable formats, and a kind-appropriate icon (code, photo,
/// or a dimmed generic glyph) for everything else the tree now shows.
struct DocumentFileIcon: View {
    let name: String

    var body: some View {
        let kind = FileKind.classify(path: name)
        if kind == .editable(.markdown) {
            MarkdownFileIcon()
        } else if kind == .binary {
            Image(systemName: kind.systemImage)
                .foregroundStyle(.tertiary)
                .frame(width: 18, height: 14)
        } else {
            Image(systemName: kind.systemImage)
                .frame(width: 18, height: 14)
        }
    }
}
