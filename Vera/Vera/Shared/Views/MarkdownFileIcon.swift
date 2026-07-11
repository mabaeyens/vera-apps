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
        switch FileKind.classify(path: name) {
        case .editable(.markdown):
            MarkdownFileIcon()
        case .editable(let format):
            Image(systemName: format.systemImage)
                .frame(width: 18, height: 14)
        case .readOnlyText:
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .frame(width: 18, height: 14)
        case .image:
            Image(systemName: "photo")
                .frame(width: 18, height: 14)
        case .binary:
            Image(systemName: "doc")
                .foregroundStyle(.tertiary)
                .frame(width: 18, height: 14)
        }
    }
}
