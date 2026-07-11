# Vera — Backlog

See [CHANGELOG.md](CHANGELOG.md) for recent changes.

## Done

- 2026-07-06 — Wired the real GitHub App client ID into Device Flow sign-in, tested it live end to end in the iOS Simulator (including hitting and resolving a real "app authorized but not installed" 404).
- 2026-07-06 — Updated PRIVACY.md for the dual auth path (PAT + Device Flow) and published a matching privacy page at askmira.es/vera/privacy in the mira-web repo.
- 2026-07-06 — Marked all 6 GitHub features "Shipped" in GITHUB_FEATURES_SPEC.md, added a Release 1.2.0 section to TEST_PLAN.md, credited Claude Code in the README.
- 2026-07-06 — Ran a high-effort code review (Opus) on the 6-feature diff; fixed all 10 confirmed findings, most notably: multi-file commits now check each file's blob SHA before writing (previously silently overwrote concurrent edits), GitHubDraftStore and the multi-file commit sheet are now branch-scoped (a same-path draft on another branch could be dropped or collide), the multi-file sheet's single-file fast path now respects the Open PR toggle, cross-branch commits fetch a fresh SHA instead of reusing a stale one, and PR working branches fork from the PR's base instead of the viewed branch.
- 2026-07-06 — Made `mabaeyens/vera-apps` public (repo history audited clean, no secrets in 153 commits).
- 2026-07-06 — Released v1.2.0: TestFlight build submitted for external review, notarized macOS DMG published on the GitHub release.
- 2026-07-10 — v1.2.0 live on TestFlight and running well on iPhone Miguel; the earlier "developer disk image could not be mounted" `/vera-validate` failure was a local Xcode tooling hiccup, not a real device/build issue.
- 2026-07-10 — Manually walked the full Release 1.2.0 checklist (repo search, conflict recovery, branch switching, branch picker, multi-file commits, Device Flow sign-in) on-device; the 2026-07-06 code-review fixes hold up in practice, not just in code review.

## Open bugs

*(none)*

---

## Pending

- **Accessibility — device pass + Nutrition Label** — code remediation F1–F6 and F8 done (labels, Dynamic Type for mono text, decorative-icon hiding, selection traits, Reduce Motion); see [ACCESSIBILITY_SPEC.md](ACCESSIBILITY_SPEC.md). F5 left as-is, F7 (preview heading/table VoiceOver structure) deferred. Procedure for the remaining on-device VoiceOver + Dynamic Type pass and the Nutrition Label mapping: [ACCESSIBILITY_SPEC.md § Device pass & Nutrition Label procedure](ACCESSIBILITY_SPEC.md#device-pass--nutrition-label-procedure).

**Note:** the "App Store Connect submission (iOS 1.0)" ASC-grid/no-build-attached issue tracked here previously is superseded — v1.2.0 is live and running well on TestFlight (confirmed 2026-07-10, including on iPhone Miguel). If a full public App Store release (distinct from TestFlight) is still wanted, that's a separate step not yet started — scope it explicitly before assuming it's done.

---

## Won't fix

- **`^1` footnote/superscript in Atlas** — cannot be delivered
- **Animated V icon** — dropped

---

## Notes

- **`DEVELOPMENT_TEAM` Team ID in `project.pbxproj`** — reviewed 2026-07-06 ahead of making the repo public: `HTVGRBVW58` is a Team ID (not a credential, grants no access) and is already exposed via every shipped IPA/TestFlight build/App Store Connect metadata. Accepted as non-sensitive; no git history rewrite planned.
- **`GitHubDraftStore` is branch-scoped** (2026-07-06 fix) — `deregisterPaths` now takes a `branch` parameter and `MultiFileCommitSheet` only ever shows drafts for the currently-browsed branch. A same-path file dirty on two branches used to collide into one draft entry and one checkbox; don't reintroduce a path-only lookup across either type.
- **Multi-file commits now pre-check blob SHAs** (`GitHubClient.commitFiles`, 2026-07-06 fix) — fetches the current tree via the recursive Git Data API and throws `.conflict` if any file's SHA moved since it was read, mirroring the single-file Contents API's optimistic concurrency. Don't strip this check back out to save the extra API call; it's what prevents multi-file commits from silently overwriting concurrent edits.
- **Preferences live in `Defaults.swift`** (added 2026-06-22) — single source of truth for every `UserDefaults`/`@AppStorage` key (`Defaults.Key.*`) and the editor font-size config (`Defaults.FontSize`: 12–32 bounds, step, platform default + `increased/decreased`). Add new prefs there, not as inline string literals. The font-size default is 17 on macOS / 20 on iOS — fixed a prior mismatch where `DocumentView` hardcoded 20 on both, disagreeing with the editor's 17 on macOS; this feeds ACCESSIBILITY_SPEC F2 (the macOS control + iOS `monoScale` share one set of numbers).
- **Root security-scoped access is balanced via `rootAccessURL`** in `FileTreeViewModel` (security review 2026-06-22) — acquired idempotently (once per root, released on root change), and released in `resetState`/`releaseAllAccess`. Don't re-add a `deinit` to release it: Swift 6 forbids a nonisolated `deinit` touching `@MainActor` state, and this single app-lifetime VM only deallocs at process exit. Don't re-introduce per-load `startAccessingSecurityScopedResource` (that was the leak).
- **macOS editor caches the selection as an `NSRange`** (`HighlightingTextView` Coordinator) — it's clamped via `validRange(_:in:)` and cleared via `invalidateCachedRange()` after external text swaps. Keep both: a stale range here was an `NSRangeException` crash on format actions after autosave reload / auto-fix.
- Reset folder picker: now Keychain-backed via `BookmarkStore` (no longer `defaults delete Vera rootFolderBookmark`); use About → "Reset Vera…".
- macOS App Sandbox **re-enabled 2026-06-21** on GA macOS 26.5.1 (the beta pre-main crash is resolved). Entitlements: app-sandbox, user-selected.read-write, files.bookmarks.app-scope, network.client, ubiquity-kvstore.
- **GitHub PAT scopes** (v1.1.0): fine-grained token needs **Contents** (Read to browse, Read+Write to commit / open PRs) and **Metadata**. Token lives in the Keychain (device-local); the repo list syncs via iCloud KVS.
- VoiceOver testing pending — `accessibilityLabel` added to all icon buttons but never verified with VoiceOver on a real device.
- v1.1.0 GitHub flows (inline browse, open-as-tab, commit/PR/diff, repo sync across devices) ship pending full on-device tap-test with a real Read+Write token.
