# Vera

A reading-first Markdown viewer and editor for iOS and macOS. Part of the Mira ecosystem.

**Zero configuration.** No vaults, no projects. Vera is a transparent window into your iCloud Drive — it shows every `.md` file you already have.

See [CHANGELOG.md](CHANGELOG.md) for recent changes.

## Features

- **Browse** — recursive file tree of every `.md` file in your chosen folder (iCloud or local); lazy per-folder expansion; folder name shown in title bar
- **Read** — native `PreviewTextView` (UITextView/NSTextView) with full cross-block selection and rich-text copy; syntax-highlighted fenced code blocks (atom-one theme via Highlightr); structured table rendering; selectable text copies rich text to clipboard
- **Edit** — syntax-highlighted editor; double-tap or Edit button to switch modes; new empty files open directly in edit mode; iOS formatting bar (undo/redo, bold, italic, heading, Atlas, more) slides up with the keyboard
- **Tabs** — tab bar visible from the first open file; "+" button opens file picker; macOS native tab bar suppressed (no system window-tab chrome); iOS bottom tab bar (up to 5 tabs)
- **Font size** — adjustable editor font size per-session
- **Atlas** — tap-to-insert syntax snippets; accessible from the toolbar in both preview and edit mode
- **Linter** — real-time Markdown syntax warnings while editing (debounced, off main thread); toggle in Settings; **Auto-fix** button repairs heading spacing, collapses blank lines, strips trailing whitespace, replaces smart quotes and dashes
- **Remove Formatting** — strip Markdown from selected text via the context menu
- **New file** — create `.md` files in any folder directly from the sidebar
- **Open file** — open any `.md` file directly without selecting a folder first; works from the sidebar or Finder (macOS)
- **Reset** — "Reset Vera" clears folder selection without deleting files; accessible from the About sheet
- **Offline** — edits and new files work without a connection; iCloud syncs on reconnect
- **Dark / light** — adaptive; follows system appearance
- **macOS sidebar** — persistent; only the toolbar button can hide it (never auto-collapses)

## Identity

| Field | Value |
|-------|-------|
| Bundle ID | `com.mab.Vera` |
| GitHub | `git@github.com:mabaeyens/vera-apps.git` |
| Swift | 6, Xcode 26+ |
| Minimum iOS | 18.0 |
| Minimum macOS | 15.0 |

For architecture, source layout, and technical decisions see [PROJECT.md](PROJECT.md).
