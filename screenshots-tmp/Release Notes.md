# Vera 1.3.0

**The native Apple app for the Markdown in your repos.**

Vera is a fast, focused editor for Markdown and code — on iPhone, iPad, and Mac,
backed by iCloud or a GitHub repo. No vault, no lock-in: the filesystem is the
data model.

## What's new

- Browse and syntax-highlight *any* text file, not just Markdown — Python,
  Swift, Go, Rust, TypeScript, JSON, YAML, and more
- Pinch-to-zoom on images, on both platforms
- Line numbers and a wrap toggle for long files
- Much clearer diagnostics when a GitHub repo can't be opened
- A dozen smaller reliability fixes across iOS and macOS

## Why Vera

1. **Fast.** Opens instantly, even on large repos.
2. **Native.** Built with SwiftUI — no Electron, no web view.
3. **Yours.** Files live in iCloud or your own GitHub repo. Vera never stores
   your content anywhere else.

> "The best editor is the one that gets out of your way."

```swift
struct Document: Identifiable {
    let id: UUID
    var title: String
    var isSynced: Bool
}
```

Learn more at [github.com/mabaeyens/vera-apps](https://github.com/mabaeyens/vera-apps).
