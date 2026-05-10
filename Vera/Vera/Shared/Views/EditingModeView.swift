import SwiftUI

struct EditingModeView: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        TextEditor(text: Binding(
            get: { viewModel.rawText },
            set: { viewModel.rawText = $0; viewModel.textDidChange() }
        ))
        .font(.system(.body, design: .monospaced))
        .padding(8)
    }
}
