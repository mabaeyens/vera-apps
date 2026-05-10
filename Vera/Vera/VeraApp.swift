import SwiftUI

@main
struct VeraApp: App {
    @State private var fileTreeVM = FileTreeViewModel()
    @State private var connectivity = ConnectivityMonitor()

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            MacRootView()
                .environment(fileTreeVM)
                .environment(connectivity)
            #else
            iOSRootView()
                .environment(fileTreeVM)
                .environment(connectivity)
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        #endif
    }
}
