import SwiftUI

#if os(macOS)
import AppKit

// Bridges NSApplicationDelegate.application(_:open:) → FileTreeViewModel.
// SwiftUI's onOpenURL may not fire for Finder double-clicks on some macOS versions,
// so we add the explicit delegate as a fallback.
class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        NotificationCenter.default.post(name: .veraOpenFile, object: url)
    }
}

extension Notification.Name {
    static let veraOpenFile = Notification.Name("com.mab.vera.openFile")
}
#endif

@main
struct VeraApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    @State private var fileTreeVM = FileTreeViewModel()
    @State private var connectivity = ConnectivityMonitor()

    init() {
        // Warm the Highlightr bundle on the main thread before any editor view is
        // constructed, preventing a nil-unwrap crash on cold launches from external apps.
        HighlightrWarmup.prime()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if os(macOS)
                MacRootView()
                    .environment(fileTreeVM)
                    .environment(connectivity)
                    .onReceive(NotificationCenter.default.publisher(for: .veraOpenFile)) { note in
                        if let url = note.object as? URL {
                            fileTreeVM.openExternalURL(url)
                        }
                    }
                #else
                iOSRootView()
                    .environment(fileTreeVM)
                    .environment(connectivity)
                #endif
            }
            .onOpenURL { url in
                fileTreeVM.openExternalURL(url)
            }
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        #endif
    }
}
