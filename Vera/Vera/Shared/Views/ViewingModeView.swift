import SwiftUI

struct ViewingModeView: View {
    @Bindable var viewModel: EditorViewModel
    @AppStorage(Defaults.Key.editorFontSize) private var fontSize = Defaults.FontSize.default

    var body: some View {
        switch viewModel.format {
        case .markdown, nil:
            MarkdownDocumentView(
                rawText: viewModel.rawText,
                fontSize: CGFloat(fontSize),
                scrollFraction: $viewModel.readingScrollFraction,
                imageBaseURL: viewModel.previewBaseURL
            )
        case .text, .json, .yaml:
            PlainDocumentView(
                rawText: viewModel.rawText,
                fontSize: CGFloat(fontSize),
                format: viewModel.format ?? .text,
                scrollFraction: $viewModel.readingScrollFraction
            )
        }
    }
}
