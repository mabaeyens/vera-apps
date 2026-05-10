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
                    // Phase 2: replace with DocumentView(url: url)
                    Text(url.deletingPathExtension().lastPathComponent)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle(url.deletingPathExtension().lastPathComponent)
                        .navigationBarTitleDisplayMode(.inline)
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
