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
                // Phase 2: replace with DocumentView(url: url)
                Text(url.lastPathComponent)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Select a file")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
