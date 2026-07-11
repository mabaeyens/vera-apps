import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Read-only viewer for image files (`FileKind.image`) opened from the file tree.
/// Fit-to-width, scrollable — no dedicated zoom/pan controls.
struct ImageViewerView: View {
    let source: DocumentSource

    @State private var imageData: Data?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let imageData, let platformImage = PlatformImage(data: imageData) {
                ScrollView([.horizontal, .vertical]) {
                    platformImage.swiftUIImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
            } else if loadFailed {
                ContentUnavailableView(
                    "Can't Load Image",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("\"\(source.displayName)\" couldn't be loaded.")
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("")
        .task { await load() }
    }

    private func load() async {
        switch source {
        case .file(let url):
            imageData = try? await DocumentStore.readData(url)
            if imageData == nil {
                // Only retry if this is genuinely an iCloud item still downloading —
                // otherwise the read failed for a real reason and retrying for 15s
                // would just stall the viewer.
                let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                    .ubiquitousItemDownloadingStatus
                if status == .notDownloaded {
                    for _ in 0..<15 {
                        try? await Task.sleep(for: .seconds(1))
                        let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                            .ubiquitousItemDownloadingStatus
                        if status == .current || status == .downloaded {
                            imageData = try? await DocumentStore.readData(url)
                            break
                        }
                    }
                }
            }
        case .gitHub(let ref):
            guard let token = CredentialStore.load() else { loadFailed = true; return }
            let client = GitHubClient(owner: ref.owner, repo: ref.repo, token: token)
            imageData = try? await client.fileData(path: ref.path, ref: ref.branch)
        }
        loadFailed = imageData == nil
    }
}

/// Thin cross-platform wrapper so `ImageViewerView` doesn't need `#if os` branches.
private struct PlatformImage {
    let swiftUIImage: Image

    init?(data: Data) {
        #if os(iOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        swiftUIImage = Image(uiImage: uiImage)
        #elseif os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        swiftUIImage = Image(nsImage: nsImage)
        #endif
    }
}
