import SwiftUI
import MarkdownUI

struct ViewingModeView: View {
    @Bindable var viewModel: EditorViewModel

    @State private var viewHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            Markdown(viewModel.rawText)
                .markdownTheme(.gitHub)
                #if os(macOS)
                .dynamicTypeSize(.xLarge)
                #endif
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
