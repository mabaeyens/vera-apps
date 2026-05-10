# Vera — Backlog

## Phase status

- **Phase 1** ✅ iCloud scanner + file tree sidebar
- **Phase 2** ✅ ViewingMode (MarkdownUI) + EditingMode (TextEditor) + auto-save
- **Phase 3** 🔜 In progress

---

## Phase 3 — Upcoming (prioritized)

1. **iOS TestFlight distribution** — archive iOS target, upload to App Store Connect, invite testers
2. **Markdown cheat sheet** — built-in `.md` resource rendered by Vera; toolbar button on both platforms
3. **Atlas drawer** — bottom sheet (iOS) / trailing panel (macOS) with tap-to-insert snippets
4. **Syntax highlighting** — Highlightr via `UIViewRepresentable` wrapping `UITextView`
5. **Onboarding view** — first-launch explanation of iCloud access and folder picker
6. **Auto-save robustness** — `NSFileVersion` conflict handling
7. **App icon dark/tinted variants** — iOS 18+ dark and tinted AppIcon variants

---

## Open bugs

*(none)*

---

## Fixed (last 30 days)

- **iOS archive: missing import** — `iOSRootView.swift` missing `import UniformTypeIdentifiers` for `.folder`. Fixed 2026-05-10.
- **CloudScanner Swift 6 actor error** — `scanDirectory` implicitly `@MainActor` on iOS 26 SDK; fixed by creating `FileManager()` in `scan()` and passing it into `Task.detached`. Fixed 2026-05-10.

---

## Notes

- Reset folder picker: `defaults delete Vera rootFolderBookmark`
- iOS untested end-to-end — needs TestFlight run before Phase 3 features ship
