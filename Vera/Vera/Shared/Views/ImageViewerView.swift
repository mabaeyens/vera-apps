import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Read-only viewer for image files (`FileKind.image`) opened from the file tree.
/// Pinch/double-tap to zoom (iOS via a real `UIScrollView`; macOS via trackpad
/// pinch), works identically for local and GitHub-sourced images since both
/// converge on the same `imageData` here.
struct ImageViewerView: View {
    let source: DocumentSource

    @State private var imageData: Data?
    @State private var loadFailed = false
    @State private var tooLarge = false

    var body: some View {
        Group {
            if let imageData, let platformImage = PlatformImage(data: imageData) {
                ZoomableImageView(image: platformImage)
            } else if tooLarge {
                ContentUnavailableView(
                    "Image Too Large",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("\"\(source.displayName)\" is over GitHub's 1 MB preview limit.")
                )
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
            do {
                imageData = try await client.fileData(path: ref.path, ref: ref.branch)
            } catch GitHubError.contentTooLarge {
                tooLarge = true
                return
            } catch {
                imageData = nil
            }
        }
        loadFailed = imageData == nil
    }
}

/// Thin cross-platform wrapper so `ImageViewerView` doesn't need `#if os` branches.
private struct PlatformImage {
    let swiftUIImage: Image
    #if os(iOS)
    let uiImage: UIImage
    #elseif os(macOS)
    let nsImage: NSImage
    #endif

    init?(data: Data) {
        #if os(iOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        self.uiImage = uiImage
        swiftUIImage = Image(uiImage: uiImage)
        #elseif os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        self.nsImage = nsImage
        swiftUIImage = Image(nsImage: nsImage)
        #endif
    }
}

#if os(iOS)
/// A real `UIScrollView` + `UIImageView`, for correct pinch-to-zoom and
/// double-tap-to-zoom — SwiftUI's `ScrollView` has no magnification support on iOS,
/// unlike `UIScrollView.minimumZoomScale`/`maximumZoomScale`, so this is the standard
/// photo-viewer pattern rather than composing `MagnificationGesture` by hand.
private struct ZoomableImageView: UIViewRepresentable {
    let image: PlatformImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = LayoutObservingScrollView()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = context.coordinator
        // UIImageView(image:) sizes its frame to the image's native pixel size, which
        // is typically far larger than the screen — layoutSubviews() below re-fits it
        // to the scroll view's actual bounds as soon as those are resolved. Relying on
        // updateUIView for that (as an earlier version did) doesn't work: SwiftUI has
        // no obligation to call it again after the view's real frame is laid out, so
        // the image could get stuck at native size with pinch doing nothing useful.
        let imageView = UIImageView(image: image.uiImage)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView
        scrollView.onLayout = { [weak coordinator = context.coordinator] in coordinator?.layout() }

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.layout()
    }

    /// Calls back into the coordinator on every real Auto Layout pass (initial layout,
    /// rotation, split-view resize) — not just when SwiftUI happens to call
    /// `updateUIView`, which isn't reliably re-invoked once the view appears.
    private final class LayoutObservingScrollView: UIScrollView {
        var onLayout: (() -> Void)?
        override func layoutSubviews() {
            super.layoutSubviews()
            onLayout?()
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        private var lastBoundsSize: CGSize = .zero

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func layout() {
            guard let scrollView, let imageView, let image = imageView.image else { return }
            let bounds = scrollView.bounds.size
            guard bounds.width > 0, bounds.height > 0, image.size.width > 0, image.size.height > 0 else { return }
            // Only re-fit on an actual size change (e.g. rotation) — updateUIView can
            // fire for unrelated SwiftUI re-renders, and resetting the frame/contentSize
            // every time would reset the user's current zoom/pan.
            guard bounds != lastBoundsSize else { return }
            lastBoundsSize = bounds
            scrollView.zoomScale = 1
            let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
            let fitSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            imageView.frame = CGRect(origin: .zero, size: fitSize)
            scrollView.contentSize = fitSize
            centerImage()
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) { centerImage() }

        private func centerImage() {
            guard let scrollView, let imageView else { return }
            let boundsSize = scrollView.bounds.size
            var frame = imageView.frame
            frame.origin.x = frame.width < boundsSize.width ? (boundsSize.width - frame.width) / 2 : 0
            frame.origin.y = frame.height < boundsSize.height ? (boundsSize.height - frame.height) / 2 : 0
            imageView.frame = frame
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let zoomRect = CGRect(
                    x: point.x - (scrollView.bounds.width / 4),
                    y: point.y - (scrollView.bounds.height / 4),
                    width: scrollView.bounds.width / 2,
                    height: scrollView.bounds.height / 2
                )
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }
    }
}
#elseif os(macOS)
/// macOS trackpad pinch routes through SwiftUI's `MagnificationGesture` cleanly, so no
/// `NSScrollView`/`NSImageView` wrapping is needed here unlike iOS.
private struct ZoomableImageView: View {
    let image: PlatformImage

    @State private var scale: CGFloat = 1
    @GestureState private var pinchScale: CGFloat = 1

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            image.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .scaleEffect(scale * pinchScale)
        }
        .gesture(
            MagnificationGesture()
                .updating($pinchScale) { value, state, _ in state = value }
                .onEnded { value in scale = max(1, min(6, scale * value)) }
        )
        .onTapGesture(count: 2) { scale = scale > 1 ? 1 : 2 }
    }
}
#endif
