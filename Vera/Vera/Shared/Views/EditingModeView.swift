import SwiftUI

struct EditingModeView: View {
    @Bindable var viewModel: EditorViewModel
    #if os(iOS)
    @AppStorage("editorFontSize") private var fontSize: Double = 20
    #else
    @AppStorage("editorFontSize") private var fontSize: Double = 17
    #endif

    var body: some View {
        HighlightingTextView(
            text: Binding(
                get: { viewModel.rawText },
                set: { viewModel.rawText = $0 }
            ),
            fontSize: CGFloat(fontSize),
            onTextChange: { viewModel.textDidChange() },
            registerInsert: { viewModel.insertAtCursor = $0 },
            registerWrap: { viewModel.wrapSelection = $0 },
            registerStrip: { viewModel.stripSelection = $0 },
            onShowAtlas: { viewModel.atlasRequested = true }
        )
    }
}
