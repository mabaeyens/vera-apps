import SwiftUI

struct EditingModeView: View {
    @Bindable var viewModel: EditorViewModel
    @AppStorage(Defaults.Key.editorFontSize) private var fontSize = Defaults.FontSize.default
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isEditing = false
    #endif
    @AppStorage(Defaults.Key.linterEnabled) private var linterEnabled = true
    @AppStorage(Defaults.Key.focusMode) private var focusMode = false
    var onAtlasRequested: () -> Void = {}
    var onCheatSheetRequested: () -> Void = {}
    var onIconHelpRequested: () -> Void = {}

    /// The user's chosen editor size, scaled for Dynamic Type on iOS so the
    /// system "Larger Text" setting moves the editor too (macOS has no Dynamic Type;
    /// the size control is the lever there).
    private var effectiveFontSize: CGFloat {
        #if os(iOS)
        CGFloat(fontSize) * dynamicTypeSize.monoScale
        #else
        CGFloat(fontSize)
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            HighlightingTextView(
                text: Binding(
                    get: { viewModel.rawText },
                    set: { viewModel.rawText = $0 }
                ),
                fontSize: effectiveFontSize,
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
                    // iPhone: the keyboard formatting bar is the inputAccessoryView.
                    // Focus Mode hides it (matching how it hides the iPad bar below).
                    return sizeClass != .regular && !focusMode
                    #else
                    return true
                    #endif
                }(),
                onEditingChanged: { editing in
                    #if os(iOS)
                    isEditing = editing
                    #endif
                },
                language: viewModel.highlightLanguage(focusMode: focusMode)
            )
            // Focus mode hides the linter so writing stays distraction-free.
            if linterEnabled && !focusMode && !viewModel.lintResults.isEmpty {
                // Auto-fix is Markdown-specific (fixMarkdown()) — offering it for JSON/YAML
                // would silently corrupt them, so only markdown gets the fix button.
                LintPanelView(
                    warnings: viewModel.lintResults,
                    onFix: viewModel.format == .markdown ? { viewModel.applyAutoFix() } : nil
                )
            }
        }
        #if os(iOS)
        // On iPad (regular width) the UIKit inputAccessoryView spans the full
        // keyboard width and overlaps the sidebar. Use a SwiftUI bar instead,
        // which is naturally constrained to the detail column.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if sizeClass == .regular && isEditing && !focusMode {
                iPadFormattingBar
            }
        }
        #endif
    }

    #if os(iOS)
    private var iPadFormattingBar: some View {
        HStack(spacing: 0) {
            // Inline formatting — all surfaced, no nested menu.
            formatButton("bold", "Bold")                 { viewModel.wrapSelection?("**", "**") }
            formatButton("italic", "Italic")             { viewModel.wrapSelection?("_", "_") }
            formatButton("strikethrough", "Strikethrough") { viewModel.wrapSelection?("~~", "~~") }
            formatButton("chevron.left.forwardslash.chevron.right", "Code") { viewModel.wrapSelection?("`", "`") }
            barDivider
            // Block formatting.
            formatButton("number", "Heading")            { viewModel.insertAtCursor?("## ") }
            formatButton("list.bullet", "List")          { viewModel.insertAtCursor?("- ") }
            formatButton("text.quote", "Quote")          { viewModel.insertAtCursor?("> ") }
            barDivider
            formatButton("paintbrush", "Format & Snippets") { onAtlasRequested() }
            barDivider
            formatButton("textformat.size.smaller", "Smaller Text") { fontSize = Defaults.FontSize.decreased(from: fontSize) }
            formatButton("textformat.size.larger", "Larger Text") { fontSize = Defaults.FontSize.increased(from: fontSize) }
            // Only genuinely-secondary, non-formatting items remain in overflow.
            Menu {
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
            .accessibilityLabel("More")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var barDivider: some View {
        Divider().frame(height: 24).padding(.horizontal, Theme.Space.xs)
    }

    private func formatButton(_ sfName: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: sfName)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .accessibilityLabel(label)
    }
    #endif
}

/// `onFix` is nil for read-only contexts (nothing to write back to) — the Auto-fix
/// button is omitted entirely in that case.
struct LintPanelView: View {
    let warnings: [LintWarning]
    var onFix: (() -> Void)? = nil
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { isExpanded.toggle() }
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
                if let onFix {
                    Button("Auto-fix", action: onFix)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                        .padding(.trailing, 12)
                }
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
