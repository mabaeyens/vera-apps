import SwiftUI

/// Routes a `DocumentSource` to the right viewer: images get `ImageViewerView`,
/// everything else (editable + read-only text) keeps using `DocumentView` unchanged.
struct DocumentOrImageView: View {
    let source: DocumentSource
    /// Owned by the tab, not by `DocumentView`, so it outlives the view being rebuilt on
    /// every tab switch. Unused for images, which have no editor.
    let editor: EditorViewModel

    var body: some View {
        if FileKind.classify(path: source.path) == .image {
            ImageViewerView(source: source)
        } else {
            DocumentView(source: source, viewModel: editor)
        }
    }
}
