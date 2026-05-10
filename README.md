# Vera

A reading-first Markdown viewer and editor for iOS and macOS. Part of the Mira ecosystem.

**Zero configuration.** No vaults, no projects. Vera is a transparent window into your iCloud Drive — it shows every `.md` file you already have.

## Features

- **Browse** — recursive file tree of every `.md` file in your chosen folder (iCloud or local)
- **Read** — rendered Markdown via MarkdownUI (tables, code blocks, task lists)
- **Edit** — syntax-highlighted editor; double-tap to switch from view to edit mode
- **Atlas** — tap-to-insert syntax snippets; accessible from the toolbar or the text context menu
- **Remove Formatting** — strip Markdown from selected text via the context menu
- **New file** — create `.md` files in any folder directly from the sidebar
- **Offline** — edits and new files work without a connection; iCloud syncs on reconnect
- **Dark / light** — adaptive; follows system appearance
- **macOS sidebar** — persistent; hide/show state remembered across relaunches

## Requirements

| Component | Version |
|-----------|---------|
| Xcode | 26+ |
| macOS (dev) | 26+ |
| iOS (device) | 18.0+ |
| macOS (device) | 15.0+ |
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
iCloud Drive / local folder
    └── FileManager recursive scan (@MainActor)
            └── FileTreeViewModel (@Observable @MainActor)
                    ├── iOS:   NavigationStack → DocumentView
                    └── macOS: NavigationSplitView → DocumentView
```

## Build

```bash
# iOS Simulator
cd Vera && xcodebuild -scheme Vera \
  -destination "platform=iOS Simulator,name=iPhone 17e" \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD"

# macOS
cd Vera && xcodebuild -scheme Vera \
  -destination "platform=macOS" \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

## SPM dependencies

- [`swift-markdown-ui`](https://github.com/gonzalezreal/swift-markdown-ui) — Markdown rendering in ViewingMode
- [`Highlightr`](https://github.com/raspu/Highlightr) — Syntax highlighting in EditingMode
