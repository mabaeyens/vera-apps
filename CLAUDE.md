# CLAUDE.md

**Vera** — iOS/macOS markdown editor. Swift 6, SwiftUI. No vault — filesystem is the data model.

## Constraints

- `@MainActor` on all ViewModels (Swift 6).
- `async/await` for all file I/O; wrap `FileManager` calls in `Task`.
- No force-unwraps in production paths.
- No App Sandbox on macOS target — causes pre-main crash on macOS 26 beta.
