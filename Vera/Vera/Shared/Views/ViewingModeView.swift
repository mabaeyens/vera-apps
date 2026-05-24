import SwiftUI

struct ViewingModeView: View {
    @Bindable var viewModel: EditorViewModel
    #if os(iOS)
    @AppStorage("editorFontSize") private var fontSize: Double = 20
    #else
    @AppStorage("editorFontSize") private var fontSize: Double = 17
    #endif

    var body: some View {
        MarkdownDocumentView(
            rawText: viewModel.rawText,
            fontSize: CGFloat(fontSize),
            scrollFraction: $viewModel.readingScrollFraction
        )
    }
}
