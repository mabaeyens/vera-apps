import Foundation

/// Single source of truth for `UserDefaults` / `@AppStorage` keys and the editor
/// font-size configuration. Keeps key strings and default values from drifting across
/// the ~10 views that read them.
enum Defaults {
    /// Persisted preference keys. The string values are unchanged from when they were
    /// inline literals, so existing installs keep their stored preferences.
    enum Key {
        static let editorFontSize       = "editorFontSize"
        static let linterEnabled        = "linterEnabled"
        static let focusMode            = "focusMode"
        static let tabBarVisible        = "tabBarVisible"
        static let hasSeenOnboarding    = "hasSeenOnboarding"
        static let pinnedFiles          = "pinnedFiles"
        static let focusModePlainTextFiles = "focusModePlainTextFiles"
        static let codeWrapEnabled      = "codeWrapEnabled"
        static let pendingReset         = "pendingReset"
        static let openFilesExpanded    = "openFilesExpanded"
        static let iCloudFolderExpanded = "iCloudFolderExpanded"
        static let githubLastOwner      = "github.lastOwner"
        static let githubLastRepo       = "github.lastRepo"
        static let githubSavedRepos     = "github.savedRepos"
    }

    /// Editor/preview font sizing. Single source for the Dynamic-Type-relevant bounds
    /// (ACCESSIBILITY_SPEC F2): the macOS in-app size control and the iOS `monoScale`
    /// path both reference these, so the editor and its size menu can never disagree.
    enum FontSize {
        static let min: Double = 12
        static let max: Double = 32
        static let step: Double = 1
        /// One standard default across iOS and macOS — previously 20/17 respectively;
        /// unified per product decision so a fresh install looks the same on both.
        static let `default`: Double = 18

        static func increased(from value: Double) -> Double { Swift.min(max, value + step) }
        static func decreased(from value: Double) -> Double { Swift.max(min, value - step) }
    }
}
