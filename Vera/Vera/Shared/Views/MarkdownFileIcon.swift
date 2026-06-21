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
