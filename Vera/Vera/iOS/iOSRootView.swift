#if os(iOS)
import SwiftUI

struct iOSRootView: View {
    @Environment(FileTreeViewModel.self) private var vm
    @State private var selectedURL: URL?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            FileTreeView(selectedURL: $selectedURL)
                .navigationTitle("Vera")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: URL.self) { url in
                    DocumentView(url: url)
                }
        }
        .onChange(of: selectedURL) { _, newURL in
            if let url = newURL {
                navigationPath.append(url)
                selectedURL = nil
            }
        }
    }
}
#endif
