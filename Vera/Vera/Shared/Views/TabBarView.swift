import SwiftUI

struct TabBarView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @AppStorage("tabBarVisible") private var tabBarVisible: Bool = true
    @State private var hasTrailingOverflow = false

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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 40)
                }
                .buttonStyle(.plain)
                .help("Open file in new tab")
                Divider().frame(height: 20)
                Button { tabBarVisible = false } label: {
                    Image(systemName: "chevron.compact.up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 40)
                }
                .buttonStyle(.plain)
                .help("Hide tab bar")
            }
            .frame(height: 40)
            .background(.bar)
            Divider()
        }
    }
}

private struct TabItemView: View {
    @Environment(FileTreeViewModel.self) private var vm
    let tab: FileTreeViewModel.TabEntry
    let isActive: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // Subtle fill for active tab
            if isActive {
                Color.primary.opacity(0.07)
            }
            HStack(spacing: 5) {
                Text(tab.name)
                    .font(isActive ? .system(size: 15, weight: .semibold) : .system(size: 15))
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 150)
                Button {
                    vm.closeTab(tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .frame(height: 40)

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
    }
}
