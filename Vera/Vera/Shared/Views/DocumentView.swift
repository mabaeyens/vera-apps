import SwiftUI

struct DocumentView: View {
    let url: URL
    @State private var viewModel: EditorViewModel
    @State private var showAtlas = false
    @State private var showCheatSheet = false

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
        .onChange(of: viewModel.atlasRequested) { _, requested in
            if requested { showAtlas = true; viewModel.atlasRequested = false }
        }
        .sheet(isPresented: $showAtlas) {
            AtlasView { item in
                switch item.kind {
                case .insert:
                    viewModel.insertSnippet(item.syntax)
                case .wrap(let prefix, let suffix):
                    viewModel.wrapOrInsert(item.syntax, prefix: prefix, suffix: suffix)
                }
            }
                #if os(iOS)
                .presentationDetents([.medium, .large])
                #else
                .frame(width: 380, height: 480)
                #endif
        }
        .sheet(isPresented: $showCheatSheet) {
            CheatSheetView()
                #if os(macOS)
                .frame(width: 480, height: 600)
                #endif
        }
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
        ToolbarItem(placement: .automatic) {
            if viewModel.mode == .editing {
                Button { showAtlas = true } label: {
                    Image(systemName: "wand.and.stars")
                }
                .help("Snippets")
            }
        }
        ToolbarItem(placement: .automatic) {
            Button { showCheatSheet = true } label: {
                Image(systemName: "book.closed")
            }
            .help("Markdown Reference")
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
