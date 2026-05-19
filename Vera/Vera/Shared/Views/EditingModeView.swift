import SwiftUI

struct EditingModeView: View {
    @Bindable var viewModel: EditorViewModel
    #if os(iOS)
    @AppStorage("editorFontSize") private var fontSize: Double = 20
    #else
    @AppStorage("editorFontSize") private var fontSize: Double = 17
    #endif
    @AppStorage("linterEnabled") private var linterEnabled = true

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
                clearAnchor: { viewModel.anchorFraction = nil }
            )
            if linterEnabled && !viewModel.lintResults.isEmpty {
                LintPanelView(warnings: viewModel.lintResults)
            }
        }
    }
}

private struct LintPanelView: View {
    let warnings: [LintWarning]
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()
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
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.bar)
            }
            .buttonStyle(.plain)

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
