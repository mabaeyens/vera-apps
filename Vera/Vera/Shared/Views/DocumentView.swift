import SwiftUI

struct DocumentView: View {
    let url: URL
    @State private var viewModel: EditorViewModel

    init(url: URL) {
        self.url = url
        self._viewModel = State(initialValue: EditorViewModel(url: url))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch viewModel.mode {
                case .viewing:
                    ViewingModeView(viewModel: viewModel)
                case .editing:
                    EditingModeView(viewModel: viewModel)
                }
            }
        }
        .navigationTitle(url.deletingPathExtension().lastPathComponent)
        .toolbar { toolbarItems }
        .task { await viewModel.load() }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            switch viewModel.mode {
            case .viewing:
                Button("Edit") { viewModel.enterEditMode() }
            case .editing:
                Button("Done") { viewModel.exitEditMode() }
                    .bold()
            }
        }
        ToolbarItem(placement: .status) {
            saveIndicator
        }
    }

    @ViewBuilder
    private var saveIndicator: some View {
        switch viewModel.saveState {
        case .saved:
            EmptyView()
        case .saving:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Saving…").font(.caption).foregroundStyle(.secondary)
            }
        case .error(let msg):
            Text(msg).font(.caption).foregroundStyle(.red)
        }
    }
}
