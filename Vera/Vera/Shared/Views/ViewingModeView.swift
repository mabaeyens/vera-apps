import SwiftUI
import MarkdownUI

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ViewingModeView: View {
    @Bindable var viewModel: EditorViewModel
    #if os(iOS)
    @AppStorage("editorFontSize") private var fontSize: Double = 20
    #else
    @AppStorage("editorFontSize") private var fontSize: Double = 17
    #endif

    @State private var viewHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            // Invisible zero-height anchor so we can read scroll offset
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: ScrollOffsetKey.self,
                        value: -geo.frame(in: .named("scrollArea")).minY
                    )
            }
            .frame(height: 0)

            Markdown(viewModel.rawText)
                .textSelection(.enabled)
                .markdownTheme(
                    Theme.gitHub
                        .text {
                            ForegroundColor(.primary)
                            FontSize(CGFloat(fontSize))
                        }
                        .table { configuration in
                            ScrollView(.horizontal, showsIndicators: false) {
                                configuration.label
                            }
                        }
                )
                .id(fontSize)
                .padding()
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { contentHeight = proxy.size.height }
                            .onChange(of: proxy.size.height) { _, h in contentHeight = h }
                    }
                )
        }
        .coordinateSpace(name: "scrollArea")
        .onPreferenceChange(ScrollOffsetKey.self) { offset in
            let scrollable = contentHeight - viewHeight
            if scrollable > 0 {
                viewModel.readingScrollFraction = max(0, min(1, offset / scrollable))
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.onAppear { viewHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { _, h in viewHeight = h }
            }
        )
        // simultaneousGesture lets scroll and double-tap coexist without the 350ms
        // hold that highPriorityGesture imposes on every touch event.
        .simultaneousGesture(
            SpatialTapGesture(count: 2, coordinateSpace: .local).onEnded { value in
                viewModel.enterEditMode(tapY: value.location.y, viewHeight: viewHeight)
            }
        )
    }
}
