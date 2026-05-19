import SwiftUI

struct TabBarView: View {
    @Environment(FileTreeViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(vm.tabs) { tab in
                        TabItemView(tab: tab, isActive: tab.id == vm.activeTabID)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 36)
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
        HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(tab.name)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: 100)
            Button {
                vm.closeTab(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.primary.opacity(0.1) : Color.clear)
        )
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.activateTab(tab.id)
        }
    }
}
