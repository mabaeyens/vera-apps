import SwiftUI

/// Routes a `DocumentSource` to the right viewer: images get `ImageViewerView`,
/// everything else (editable + read-only text) keeps using `DocumentView` unchanged.
struct DocumentOrImageView: View {
    let source: DocumentSource

    var body: some View {
        if FileKind.classify(extension: source.fileExtension) == .image {
            ImageViewerView(source: source)
        } else {
            DocumentView(source: source)
        }
    }
}
