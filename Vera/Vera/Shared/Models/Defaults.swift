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
        static let hasSeenOnboarding    = "hasSeenOnboarding"
        static let pinnedFiles          = "pinnedFiles"
        static let recentFiles          = "recentFiles"
        static let focusModePlainTextFiles = "focusModePlainTextFiles"
        static let codeWrapEnabled      = "codeWrapEnabled"
        static let lineNumbersEnabled   = "lineNumbersEnabled"
        static let pendingReset         = "pendingReset"
        static let openFilesExpanded    = "openFilesExpanded"
        static let iCloudFolderExpanded = "iCloudFolderExpanded"
        static let githubLastOwner      = "github.lastOwner"
        static let githubLastRepo       = "github.lastRepo"
        static let githubSavedRepos     = "github.savedRepos"
        static let showHiddenFiles      = "showHiddenFiles"
    }

    /// Hidden files and folders (names starting with a dot, like `.claude.json`) in the
    /// sidebar and the Open panel. On by default in Debug builds so development sessions
    /// can reach dotfiles; off in release builds until the user turns it on.
    #if DEBUG
    static let showHiddenFilesDefault = true
    #else
    static let showHiddenFilesDefault = false
    #endif

    /// Current value for code outside SwiftUI (the scanner runs off the main actor).
    /// An unset key falls back to the build default, not to `false`.
    nonisolated static var showHiddenFiles: Bool {
        UserDefaults.standard.object(forKey: Key.showHiddenFiles) as? Bool ?? showHiddenFilesDefault
    }

    /// Editor/preview font sizing. Single source for the Dynamic-Type-relevant bounds
    /// (ACCESSIBILITY_SPEC F2): the macOS in-app size control and the iOS `monoScale`
    /// path both reference these, so the editor and its size menu can never disagree.
    enum FontSize {
        static let min: Double = 12
        static let max: Double = 32
        static let step: Double = 1
        /// One standard default across iOS and macOS (previously 20/17 respectively, then
        /// 18) so a fresh install looks the same on both. Must stay equal to
        /// `Theme.Typography.codeSize`, which is what DESIGN.md documents; the two
        /// disagreeing (15 vs 18) is what let editor and preview drift apart.
        static let `default`: Double = 15

        static func increased(from value: Double) -> Double { Swift.min(max, value + step) }
        static func decreased(from value: Double) -> Double { Swift.max(min, value - step) }
    }
}
