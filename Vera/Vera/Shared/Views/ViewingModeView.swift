import SwiftUI

struct ViewingModeView: View {
    @Bindable var viewModel: EditorViewModel
    @AppStorage(Defaults.Key.editorFontSize) private var fontSize = Defaults.FontSize.default

    var body: some View {
        switch viewModel.format {
        case .markdown:
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
                language: viewModel.format?.highlightLanguage,
                scrollFraction: $viewModel.readingScrollFraction
            )
        case nil:
            // Not one of the 4 rich formats — a source/text file with no format-specific
            // handling, but still editable (see EditorViewModel.canEdit). Resolve a
            // Highlightr language from the extension so e.g. .py/.entitlements get correct
            // highlighting instead of being misread as Markdown.
            VStack(spacing: 0) {
                PlainDocumentView(
                    rawText: viewModel.rawText,
                    fontSize: CGFloat(fontSize),
                    language: FileKind.classify(path: viewModel.source.path).readOnlyLanguage,
                    scrollFraction: $viewModel.readingScrollFraction
                )
                // No onFix: Auto-fix is Markdown-specific (fixMarkdown()), not tied to
                // editability — these files are editable, just via the plain editor.
                if !viewModel.lintResults.isEmpty {
                    LintPanelView(warnings: viewModel.lintResults)
                }
            }
        }
    }
}
