# CLAUDE.md

**Vera** — iOS/macOS markdown editor. Swift 6, SwiftUI. No vault — filesystem is the data model.

## Constraints

- `@MainActor` on all ViewModels (Swift 6).
- `async/await` for all file I/O; wrap `FileManager` calls in `Task`.
- No force-unwraps in production paths.
- No App Sandbox on macOS target — causes pre-main crash on macOS 26 beta.
- `PrivacyInfo.xcprivacy` exists at `Vera/Vera/PrivacyInfo.xcprivacy` — do not recreate it. The target uses a synchronized root group, so it is bundled automatically (confirmed in built `Vera.app/Contents/Resources/`); no manual Xcode step needed.
