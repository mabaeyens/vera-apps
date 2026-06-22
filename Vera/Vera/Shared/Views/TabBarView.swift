import SwiftUI

struct TabBarView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(Defaults.Key.tabBarVisible) private var tabBarVisible: Bool = true
    @State private var hasTrailingOverflow = false

    private var tabHeight: CGFloat {
        #if os(macOS)
        return 40
        #else
        return horizontalSizeClass == .regular ? 52 : 40
        #endif
    }
    private var iconFont: Font {
        #if os(macOS)
        return .caption
        #else
        return horizontalSizeClass == .regular ? .callout : .caption
        #endif
    }
    private var addButtonWidth: CGFloat {
        #if os(macOS)
        return 32
        #else
        return horizontalSizeClass == .regular ? 44 : 32
        #endif
    }
    private var hideButtonWidth: CGFloat {
        #if os(macOS)
        return 28
        #else
        return horizontalSizeClass == .regular ? 40 : 28
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(vm.tabs) { tab in
                            TabItemView(tab: tab, isActive: tab.id == vm.activeTabID)
                        }
                    }
                }
                .onScrollGeometryChange(for: Bool.self) { geo in
                    (geo.contentSize.width - geo.containerSize.width - geo.contentOffset.x) > 8
                } action: { _, hasMore in
                    hasTrailingOverflow = hasMore
                }
                .overlay(alignment: .trailing) {
                    if hasTrailingOverflow {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: Color.primary.opacity(0.10), location: 1),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 40)
                        .allowsHitTesting(false)
                    }
                }
                Divider().frame(height: 20)
                Button {
                    NotificationCenter.default.post(name: .veraOpenPicker, object: nil)
                } label: {
                    Image(systemName: "plus")
                        .font(iconFont)
                        .foregroundStyle(.secondary)
                        .frame(width: addButtonWidth, height: tabHeight)
                }
                .buttonStyle(.plain)
                .help("Open file in new tab")
                .accessibilityLabel("Open file in new tab")
                Divider().frame(height: 20)
                Button { tabBarVisible = false } label: {
                    Image(systemName: "chevron.compact.up")
                        .font(iconFont)
                        .foregroundStyle(.secondary)
                        .frame(width: hideButtonWidth, height: tabHeight)
                }
                .buttonStyle(.plain)
                .help("Hide tab bar")
                .accessibilityLabel("Hide tab bar")
            }
            .frame(height: tabHeight)
            .background(.bar)
            Divider()
        }
    }
}

private struct TabItemView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let tab: FileTreeViewModel.TabEntry
    let isActive: Bool

    private var tabHeight: CGFloat {
        #if os(macOS)
        return 40
        #else
        return horizontalSizeClass == .regular ? 52 : 40
        #endif
    }
    private var closeSize: CGFloat {
        #if os(macOS)
        return 14
        #else
        return horizontalSizeClass == .regular ? 20 : 14
        #endif
    }
    private var closeFont: CGFloat {
        #if os(macOS)
        return 8
        #else
        return horizontalSizeClass == .regular ? 11 : 8
        #endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Subtle fill for active tab
            if isActive {
                Color.primary.opacity(0.07)
            }
            HStack(spacing: 5) {
                Text(tab.name)
                    .font(isActive ? .subheadline.weight(.semibold) : .subheadline)
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 150)
                Button {
                    vm.closeTab(tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: closeFont, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: closeSize, height: closeSize)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close \(tab.name)")
            }
            .padding(.horizontal, 10)
            .frame(height: tabHeight)

            // Bottom accent bar for active tab
            if isActive {
                Rectangle()
                    .frame(height: 2)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.activateTab(tab.id)
        }
        .accessibilityLabel(tab.name)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
