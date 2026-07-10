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

/// File-row icon that picks the right glyph for the document's format — the Markdown
/// mark for `.md`, an SF Symbol for the other supported text formats.
struct DocumentFileIcon: View {
    let name: String

    var body: some View {
        let format = DocumentFormat.from(path: name)
        switch format {
        case nil, .markdown:
            MarkdownFileIcon()
        case .text, .json, .yaml:
            Image(systemName: format?.systemImage ?? "doc.plaintext")
                .frame(width: 18, height: 14)
        }
    }
}
