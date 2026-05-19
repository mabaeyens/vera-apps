import SwiftUI

struct DocumentView: View {
    let url: URL
    @State private var viewModel: EditorViewModel
    @State private var showAtlas = false
    @State private var showCheatSheet = false
    @State private var showIconHelp = false
    #if os(iOS)
    @AppStorage("editorFontSize") private var fontSize: Double = 20
    #else
    @AppStorage("editorFontSize") private var fontSize: Double = 20
    #endif

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
        .navigationTitle("")
        .toolbar { toolbarItems }
        .task { await viewModel.load() }
        .onChange(of: viewModel.atlasRequested) { _, requested in
            if requested { showAtlas = true; viewModel.atlasRequested = false }
        }
        .sheet(isPresented: $showAtlas) {
            AtlasView(
                onTap: { item in
                    switch item.kind {
                    case .insert:
                        viewModel.insertSnippet(item.syntax)
                    case .wrap(let prefix, let suffix):
                        viewModel.wrapOrInsert(item.syntax, prefix: prefix, suffix: suffix)
                    }
                },
                onRemoveFormatting: { viewModel.stripAtCursor() }
            )
            #if os(iOS)
            .presentationDetents([.large])
            #else
            .frame(width: 380, height: 560)
            #endif
        }
        .sheet(isPresented: $showCheatSheet) {
            CheatSheetView()
                #if os(macOS)
                .frame(width: 480, height: 600)
                #endif
        }
        #if os(iOS)
        .sheet(isPresented: $showIconHelp) {
            IconHelpView()
        }
        #endif
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
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
            Button { showIconHelp = true } label: {
                Image(systemName: "questionmark.circle")
            }
        }
        // Explicit .topBarTrailing keeps Atlas visible; .automatic can route elsewhere in compact mode
        ToolbarItem(placement: .topBarTrailing) {
            Button { showAtlas = true } label: {
                Image(systemName: "wand.and.stars")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { fontSize = min(32, fontSize + 1) } label: {
                    Label("Larger Text", systemImage: "textformat.size.larger")
                }
                Button { fontSize = max(12, fontSize - 1) } label: {
                    Label("Smaller Text", systemImage: "textformat.size.smaller")
                }
                if viewModel.mode == .viewing {
                    Divider()
                    Button { showCheatSheet = true } label: {
                        Label("Markdown Reference", systemImage: "book.closed")
                    }
                }
            } label: {
                Image(systemName: "textformat.size")
            }
        }
        #else
        ToolbarItem(placement: .automatic) {
            Button { showAtlas = true } label: {
                Image(systemName: "wand.and.stars")
            }
            .help("Atlas — AI writing assistant")
        }
        if viewModel.mode == .viewing {
            ToolbarItem(placement: .automatic) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.rawText, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy all text")
            }
        }
        ToolbarItem(placement: .automatic) {
            Button { showCheatSheet = true } label: {
                Image(systemName: "book.closed")
            }
            .help("Markdown Reference")
        }
        ToolbarItem(placement: .automatic) {
            Button { fontSize = max(12, fontSize - 1) } label: {
                Image(systemName: "textformat.size.smaller")
            }
            .help("Decrease font size")
        }
        ToolbarItem(placement: .automatic) {
            Button { fontSize = min(32, fontSize + 1) } label: {
                Image(systemName: "textformat.size.larger")
            }
            .help("Increase font size")
        }
        #endif
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
