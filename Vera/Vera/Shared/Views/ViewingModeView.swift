import SwiftUI
import MarkdownUI

struct ViewingModeView: View {
    @Bindable var viewModel: EditorViewModel
    #if os(iOS)
    @AppStorage("editorFontSize") private var fontSize: Double = 20
    #else
    @AppStorage("editorFontSize") private var fontSize: Double = 17
    #endif

    @State private var viewHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            Markdown(viewModel.rawText)
                .markdownTheme(.gitHub)
                .markdownTextStyle {
                    FontSize(CGFloat(fontSize))
                }
                .padding()
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            GeometryReader { proxy in
                Color.clear.onAppear { viewHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { _, h in viewHeight = h }
            }
        )
        .onTapGesture(count: 2, coordinateSpace: .local) { location in
            viewModel.enterEditMode(tapY: location.y, viewHeight: viewHeight)
        }
    }
}
