# Vera

A native git-aware file editor for iOS and macOS. Part of the Mira ecosystem.

**Zero configuration.** No vaults, no projects. Vera is a transparent window into your iCloud Drive — it shows every file you already have — and, opt-in, every file in your **GitHub repositories**. Any file Vera can open — Markdown, code, JSON/YAML, plain text — is editable, not just read-only.

**Open source.** The full source is public on GitHub — see the [repository](https://github.com/mabaeyens/vera-apps) to browse the code or verify the [privacy policy](PRIVACY.md).

See [CHANGELOG.md](CHANGELOG.md) for recent changes.

## Download

- **macOS** — grab the latest notarized `.dmg` from the [Releases page](https://github.com/mabaeyens/vera-apps/releases/latest). It's Developer ID-signed and notarized, so it opens without Gatekeeper warnings — no App Store needed.
- **iOS / iPadOS** — via TestFlight (public link coming once the build clears App Review).

## Features

- **Browse** — recursive file tree of every file Vera can open in your chosen folder (iCloud or local) — Markdown, code (Swift, Python, Go, Rust, shell, SQL, TypeScript/TSX, JavaScript/CJS, and more), JSON/YAML, plain text, images; the local folder and each GitHub repo collapse via the same leading-chevron disclosure; lazy per-folder expansion; curated per-language icons, Markdown files carry the Markdown mark
- **GitHub (opt-in)** — connect a repo with a fine-grained token; browse its full file tree in the sidebar, open files in tabs alongside your local files, create new ones, edit with the full editor, then **commit** straight to the branch or **open a pull request**; **What Changed** shows a native diff (and recent commit history) when a file moved on. The token stays in your device Keychain; the list of connected repos syncs via iCloud. GitHub.com only — GitHub Enterprise Server isn't supported. Pull down the sidebar on iOS/iPadOS to refresh local files and every connected repo
- **Read** — native `PreviewTextView` (UITextView/NSTextView) with full cross-block selection and rich-text copy; syntax-highlighted fenced code blocks and code files (atom-one theme via Highlightr); structured table rendering; selectable text copies rich text to clipboard; pinch-to-zoom on images (mouse/trackpad zoom controls on macOS)
- **Edit** — every supported file type is editable, not just Markdown: syntax-highlighted editor with an adjustable font size; double-tap or Edit button to switch modes; new empty files open directly in edit mode; the Markdown-specific formatting bar (undo/redo, bold, italic, heading, Atlas, more) shows only for `.md` files — code and other text files stay a clean syntax-highlighted editor with no risk of inserting stray formatting characters
- **Tabs** — tab bar visible from the first open file; "+" button opens file picker; macOS native tab bar suppressed (no system window-tab chrome); iOS bottom tab bar (up to 5 tabs)
- **Font size** — adjustable editor font size per-session, applies to Markdown prose, tables, and syntax-highlighted code alike
- **Atlas** — tap-to-insert Markdown syntax snippets; accessible from the toolbar in both preview and edit mode for Markdown files
- **Linter** — real-time Markdown syntax warnings while editing (debounced, off main thread); toggle in Settings; **Auto-fix** button repairs heading spacing, collapses blank lines, strips trailing whitespace, replaces smart quotes and dashes
- **Remove Formatting** — strip Markdown from selected text via the context menu
- **Focus Mode** — distraction-free writing: hides the formatting bar and linter (and on Mac the tab bar and sidebar too)
- **Icon Guide** — a reference of every icon in the app, opened from the ••• overflow menu on iPhone, iPad and Mac
- **New file** — create a Markdown, text, JSON, or YAML file in any folder directly from the sidebar; any existing file of any supported type opens straight into the editor
- **Open file** — open any file directly without selecting a folder first; works from the sidebar or Finder (macOS)
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

## License

[MIT](LICENSE) © Miguel A. Baeyens. Free forever, no account, nothing sent anywhere.

Built with [Claude Code](https://claude.com/claude-code).
