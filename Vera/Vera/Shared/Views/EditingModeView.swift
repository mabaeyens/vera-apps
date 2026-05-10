import SwiftUI

struct EditingModeView: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        HighlightingTextView(
            text: Binding(
                get: { viewModel.rawText },
                set: { viewModel.rawText = $0 }
            ),
            onTextChange: { viewModel.textDidChange() },
            registerInsert: { viewModel.insertAtCursor = $0 },
            registerWrap: { viewModel.wrapSelection = $0 },
            registerStrip: { viewModel.stripSelection = $0 },
            onShowAtlas: { viewModel.atlasRequested = true }
        )
    }
}
