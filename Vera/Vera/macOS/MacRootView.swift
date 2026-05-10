#if os(macOS)
import SwiftUI

struct MacRootView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @State private var selectedURL: URL?

    var body: some View {
        NavigationSplitView {
            FileTreeView(selectedURL: $selectedURL)
                .navigationTitle("Vera")
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let url = selectedURL {
                DocumentView(url: url)
            } else {
                ContentUnavailableView("Select a file", systemImage: "doc.text")
            }
        }
    }
}
#endif
