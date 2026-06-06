import SwiftUI

struct EditingModeView: View {
    @Bindable var viewModel: EditorViewModel
    #if os(iOS)
    @AppStorage("editorFontSize") private var fontSize: Double = 20
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var isEditing = false
    #else
    @AppStorage("editorFontSize") private var fontSize: Double = 17
    #endif
    @AppStorage("linterEnabled") private var linterEnabled = true
    var onAtlasRequested: () -> Void = {}
    var onCheatSheetRequested: () -> Void = {}
    var onIconHelpRequested: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
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
                scrollFraction: viewModel.anchorFraction,
                clearAnchor: { viewModel.anchorFraction = nil },
                onAtlasRequested: onAtlasRequested,
                onCheatSheetRequested: onCheatSheetRequested,
                onIconHelpRequested: onIconHelpRequested,
                useInputAccessory: {
                    #if os(iOS)
                    return sizeClass != .regular
                    #else
                    return true
                    #endif
                }(),
                onEditingChanged: { editing in
                    #if os(iOS)
                    isEditing = editing
                    #endif
                }
            )
            if linterEnabled && !viewModel.lintResults.isEmpty {
                LintPanelView(warnings: viewModel.lintResults, onFix: { viewModel.applyAutoFix() })
            }
        }
        #if os(iOS)
        // On iPad (regular width) the UIKit inputAccessoryView spans the full
        // keyboard width and overlaps the sidebar. Use a SwiftUI bar instead,
        // which is naturally constrained to the detail column.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if sizeClass == .regular && isEditing {
                iPadFormattingBar
            }
        }
        #endif
    }

    #if os(iOS)
    private var iPadFormattingBar: some View {
        HStack(spacing: 0) {
            formatButton("bold")         { viewModel.wrapSelection?("**", "**") }
            formatButton("italic")       { viewModel.wrapSelection?("_", "_") }
            formatButton("number")       { viewModel.insertAtCursor?("## ") }
            formatButton("paintbrush") { onAtlasRequested() }
            Menu {
                Button { viewModel.wrapSelection?("~~", "~~") } label: {
                    Label("Strikethrough", systemImage: "strikethrough")
                }
                Button { viewModel.wrapSelection?("`", "`") } label: {
                    Label("Code", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Button { viewModel.insertAtCursor?("- ") } label: {
                    Label("List", systemImage: "list.bullet")
                }
                Button { viewModel.insertAtCursor?("> ") } label: {
                    Label("Quote", systemImage: "text.quote")
                }
                Divider()
                Button {
                    fontSize = min(32, fontSize + 1)
                } label: {
                    Label("Larger Text", systemImage: "textformat.size.larger")
                }
                Button {
                    fontSize = max(12, fontSize - 1)
                } label: {
                    Label("Smaller Text", systemImage: "textformat.size.smaller")
                }
                Divider()
                Button { onCheatSheetRequested() } label: {
                    Label("Markdown Reference", systemImage: "book.closed")
                }
                Button { onIconHelpRequested() } label: {
                    Label("Icon Help", systemImage: "questionmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func formatButton(_ sfName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: sfName)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
    }
    #endif
}

private struct LintPanelView: View {
    let warnings: [LintWarning]
    let onFix: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text("\(warnings.count) warning\(warnings.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Auto-fix", action: onFix)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .padding(.trailing, 12)
            }
            .background(.bar)

            if isExpanded {
                Divider()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(warnings.prefix(50))) { w in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("L\(w.line)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                                Text(w.message)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 150)
                .background(.bar)
            }
        }
    }
}
