# Vera

A reading-first Markdown viewer and editor for iOS and macOS. Part of the Mira ecosystem.

**Zero configuration.** No vaults, no projects. Vera is a transparent window into your iCloud Drive — it shows every `.md` file you already have.

## Features (roadmap)

| Phase | Status | Feature |
|-------|--------|---------|
| 1 | In progress | iCloud file tree — browse all `.md` files |
| 2 | Planned | Viewer (MarkdownUI) + Editor (TextEditor) with Smart Anchor |
| 3 | Planned | Atlas drawer (tap-to-insert syntax) + syntax highlighting |

## Requirements

| Component | Version |
|-----------|---------|
| Xcode | 26+ |
| macOS (dev) | 26+ |
| iOS (device) | 26+ |
| Swift | 6 |

## Project structure

```
Vera/
├── Shared/          # Cross-platform: Models, ViewModels, Views
├── iOS/             # iOS entry point and navigation
├── macOS/           # macOS entry point and NavigationSplitView
└── Assets.xcassets/
Design/              # App icon source files
```

## Architecture

```
iCloud Drive (Vera container)
    └── CloudScanner (async, recursive)
            └── FileTreeViewModel (@Observable @MainActor)
                    ├── iOS:   NavigationStack → DocumentView
                    └── macOS: NavigationSplitView → DocumentView
```

## Build

```bash
xcodebuild -scheme Vera \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

## SPM dependencies

- [`swift-markdown-ui`](https://github.com/gonzalezreal/swift-markdown-ui) — Markdown rendering in ViewingMode
- [`Highlightr`](https://github.com/raspu/Highlightr) — Syntax highlighting in EditingMode (Phase 3)
