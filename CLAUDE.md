# CLAUDE.md — Vera

Vera is a reading-first Markdown viewer and editor for iOS and macOS.
It is part of the Mira ecosystem. The GitHub repository is `mabaeyens/vera-apps`.

---

## Project identity

| Field | Value |
|-------|-------|
| App name | Vera |
| Bundle ID (iOS) | com.mira.vera.ios |
| Bundle ID (macOS) | com.mira.vera.macos |
| Xcode project | `Vera.xcodeproj` |
| Swift | 6 |
| Xcode | 26+ |
| Minimum iOS | 18.0 |
| Minimum macOS | 15.0 |
| GitHub remote | `git@github.com:mabaeyens/vera-apps.git` |

---

## Source layout

```
Vera/
├── Shared/          # All cross-platform code
│   ├── Models/      # FileNode, DocumentStore, DownloadState
│   ├── ViewModels/  # FileTreeViewModel, EditorViewModel
│   └── Views/       # FileTreeView, DocumentView, AtlasDrawer, …
├── iOS/             # iOS-specific entry point, navigation stack
├── macOS/           # macOS-specific entry point, NavigationSplitView
└── Assets.xcassets/
Design/              # App icon SVG, mockups
BACKLOG.md           # Working board (Upcoming / Known bugs / Notes)
BUGS.md              # Open bugs only
```

---

## Architecture

```
iCloud Drive (.md files)
    └── FileManager recursive scanner
            └── FileTreeViewModel (ObservableObject)
                    ├── iOS:   NavigationStack (list → document)
                    └── macOS/iPadOS: NavigationSplitView (sidebar | center | trailing)
```

No server, no networking. 100% local + iCloud.

---

## Key technical decisions

- **iCloud access:** uses `NSUbiquitousContainerIdentifier` entitlement with the shared iCloud Drive container (`iCloud.com.mab.Vera`). No custom container — reads from the user's existing Drive.
- **Markdown rendering (ViewingMode):** MarkdownUI (SPM). Richer fidelity than `AttributedString(markdown:)` — handles tables, code blocks, task lists correctly.
- **Markdown editing (EditingMode):** Native `TextEditor` / `UITextView` wrapping raw `.md` text.
- **Smart Anchor (Phase 2):** tap-to-cursor mapping via TextKit 2 `NSTextLayoutManager`. Isolated in `SmartAnchorResolver.swift`.
- **Auto-save:** debounced write via `Combine` publisher (500 ms delay after last keystroke).
- **Cloud-awareness:** check `ubiquitousItemDownloadingStatusKey` before opening; trigger `startDownloadingUbiquitousItem` on tap.
- **No external databases, no vaults, no configuration files.** The file tree IS the data model.

---

## Coding conventions

- Follow the same file/folder conventions as `mira-apps/OllamaSearch/`.
- `@MainActor` on all ViewModels.
- Use `async/await` for file I/O (wrap `FileManager` calls in `Task`).
- No force-unwraps in production paths.
- Entitlements: separate `Vera-iOS.entitlements` and `Vera-macOS.entitlements`.

---

## Build commands

```bash
# iOS Simulator
xcodebuild -scheme Vera \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD"

# macOS
xcodebuild -scheme Vera \
  -destination "platform=macOS" \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

---

## Safety rules

- Never delete files, branches, or the repository without explicit approval.
- Never commit API keys or secrets.
- `git pull origin main` before every commit or push.
- All GitHub operations use `gh` at `/opt/homebrew/bin/gh`.

---

## Phases (high-level)

| Phase | Deliverable |
|-------|-------------|
| 1 | iCloud scanner + file tree sidebar |
| 2 | ViewingMode (MarkdownUI) + EditingMode (TextEditor) + Smart Anchor |
| 3 | Atlas drawer + syntax highlighting + auto-save polish |
