import SwiftUI

/// Sort options for the sidebar, shared by the iPhone/iPad and Mac "More options" menus.
/// The scanner reads the same keys (`Defaults.sortKey`...), and `FileTreeView` rescans
/// when any of them change.
struct SortMenu: View {
    @AppStorage(Defaults.Key.sortKey) private var sortKeyRaw = Defaults.SortKey.dateModified.rawValue
    @AppStorage(Defaults.Key.sortAscending) private var ascending = false
    @AppStorage(Defaults.Key.foldersOnTop) private var foldersOnTop = false

    var body: some View {
        Menu {
            Picker("Sort By", selection: $sortKeyRaw) {
                ForEach(Defaults.SortKey.allCases, id: \.rawValue) { key in
                    Text(key.title).tag(key.rawValue)
                }
            }
            Picker("Order", selection: $ascending) {
                Text("Ascending").tag(true)
                Text("Descending").tag(false)
            }
            Toggle("Folders on Top", isOn: $foldersOnTop)
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }
}
