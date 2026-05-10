import SwiftUI

@main
struct VeraApp: App {
    @State private var fileTreeVM = FileTreeViewModel()

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            MacRootView()
                .environment(fileTreeVM)
            #else
            iOSRootView()
                .environment(fileTreeVM)
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        #endif
    }
}
