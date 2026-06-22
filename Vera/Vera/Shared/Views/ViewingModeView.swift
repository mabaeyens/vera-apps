import SwiftUI

struct ViewingModeView: View {
    @Bindable var viewModel: EditorViewModel
    @AppStorage(Defaults.Key.editorFontSize) private var fontSize = Defaults.FontSize.default

    var body: some View {
        MarkdownDocumentView(
            rawText: viewModel.rawText,
            fontSize: CGFloat(fontSize),
            scrollFraction: $viewModel.readingScrollFraction
        )
    }
}
