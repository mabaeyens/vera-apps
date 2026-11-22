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
- 2026-07-26 — **iPad font-size hang resolved** ([IPAD_FONT_SIZE_HANG.md](IPAD_FONT_SIZE_HANG.md)), confirmed on a physical iPad against the canonical repro (`RepoStatusCard.tsx`, Preview mode, tap A/A). It was not fixed by a targeted fix: three of those were tried and all three failed. It went away with the 2026-07-26 performance and typography work, most likely `c0ff244` (1 MB highlight cap, typed `.task(id:)` key, parsing off the main actor). Settles the contradiction tracked here earlier: `CHANGELOG.md`'s v1.3.1 claim to have fixed it was **wrong** — the hang survived that release. The real fix is in the unreleased 2026-07-26 work, so the next release notes should say so rather than repeating v1.3.1's claim.
- 2026-07-10 — Manually walked the full Release 1.2.0 checklist (repo search, conflict recovery, branch switching, branch picker, multi-file commits, Device Flow sign-in) on-device; the 2026-07-06 code-review fixes hold up in practice, not just in code review.
- 2026-11-22: **v1.3.3 shipped.** Go to File, Outline, working relative/anchor/wiki links, rename from the sidebar, list continuation with Tab/Shift-Tab, chunked preview rendering, and autosave that refuses to overwrite a file changed on disk. TestFlight build 4 uploaded, notarized DMG attached to the GitHub release, and the iOS version submitted for App Review as the first public App Store release (listing completed: subtitle, categories, privacy URL, age rating 4+, free, review notes, five iPhone and five iPad screenshots, App Privacy "Data Not Collected").
- 2026-11-22: Added a UI test suite (`Vera/VeraUITests`, `scripts/ui-tests.sh`) that runs on simulators and on the physical iPhone against a seeded fixture folder. It found three real bugs that are now fixed: a link into a long document opened at the top, an Outline jump while already editing did nothing, and wikilinks failed to resolve through a symlinked path.
- 2026-11-22: Release listing wording corrected: the App Store description claimed a double-tap to edit that does not exist and still described tabs, which were removed in 1.3.2.

## Open bugs

(none)

---

## Pending

- **Accessibility — device pass + Nutrition Label** — code remediation F1–F6 and F8 done (labels, Dynamic Type for mono text, decorative-icon hiding, selection traits, Reduce Motion); see [ACCESSIBILITY_SPEC.md](ACCESSIBILITY_SPEC.md). F5 left as-is, F7 (preview heading/table VoiceOver structure) deferred. Procedure for the remaining on-device VoiceOver + Dynamic Type pass and the Nutrition Label mapping: [ACCESSIBILITY_SPEC.md § Device pass & Nutrition Label procedure](ACCESSIBILITY_SPEC.md#device-pass--nutrition-label-procedure).

- **App Review for iOS 1.3.3**: submitted 2026-11-22, waiting for review. If it is rejected, fix and resubmit; the listing, notes and screenshots are already in place. After approval, check the release type (manual vs after approval) and add the store link to the README.
- **Changed-on-disk notice is hidden while typing**: when an outside edit makes the open buffer stale, autosave is blocked and the Reload/Overwrite notice only shows after leaving edit mode (the status toolbar item is under the keyboard). While typing there is no sign that saving stopped. Needs a visible notice above the keyboard.
- **UI items still untested:** the iPad close dialog with an unsaved or conflicted file, undo of a Return as one step, and iCloud conflict copies. Shift-Tab (outdent) is not implemented on iOS, only Tab.
- **⌘P on iPad simulator does nothing**: the shortcut is wired in `VeraCommands` and the root views and works from the menu, but a synthesized ⌘P in a UI test had no effect on the iPad simulator. Not determined whether it is a simulator or a real-keyboard problem; check on a physical iPad with a keyboard.
- **Release tooling is stale**: `/vera-ship` and `/vera-release` still describe a `1.0.x` version line (the project is on 1.3.x), and the TestFlight "What to Test" step finds a build by bare build number, so it can write to an old expired build with the same number from another version train. Match on the version train instead.
- **Mac App Store record**: App Store Connect has an empty macOS 1.0 version. Mac ships as the notarized DMG, so it is intentionally unused.

---

## Won't fix

- **`^1` footnote/superscript in Atlas** — cannot be delivered
- **Animated V icon** — dropped

---

## Notes

- **`DEVELOPMENT_TEAM` Team ID in `project.pbxproj`** — reviewed 2026-07-06 ahead of making the repo public: `HTVGRBVW58` is a Team ID (not a credential, grants no access) and is already exposed via every shipped IPA/TestFlight build/App Store Connect metadata. Accepted as non-sensitive; no git history rewrite planned.
- **`GitHubDraftStore` is branch-scoped** (2026-07-06 fix) — `deregisterPaths` now takes a `branch` parameter and `MultiFileCommitSheet` only ever shows drafts for the currently-browsed branch. A same-path file dirty on two branches used to collide into one draft entry and one checkbox; don't reintroduce a path-only lookup across either type.
- **Multi-file commits now pre-check blob SHAs** (`GitHubClient.commitFiles`, 2026-07-06 fix) — fetches the current tree via the recursive Git Data API and throws `.conflict` if any file's SHA moved since it was read, mirroring the single-file Contents API's optimistic concurrency. Don't strip this check back out to save the extra API call; it's what prevents multi-file commits from silently overwriting concurrent edits.
- **Preferences live in `Defaults.swift`** (added 2026-06-22) — single source of truth for every `UserDefaults`/`@AppStorage` key (`Defaults.Key.*`) and the editor font-size config (`Defaults.FontSize`: 12–32 bounds, step, platform default + `increased/decreased`). Add new prefs there, not as inline string literals. **Updated 2026-07-26:** the default is now **15 on both platforms**, equal to `Theme.Typography.codeSize` and to what DESIGN.md always documented (it had drifted 17/20 → 18 → 15, with `Theme` and `Defaults` disagreeing). `monoScale` is **deleted**: every surface resolves size through `Theme.Typography.size(_:preference:typeSize:)` on Apple's `.body` Dynamic Type ramp — the ramp MarkdownUI already applies internally. MarkdownUI is the one caller handed an *unscaled* size; giving it a scaled one double-scales. Three competing ramps (Vera's in the editor and code blocks, Apple's in MarkdownUI, none in tables) was the cause of the edit-vs-preview size mismatch.
- **Root security-scoped access is balanced via `rootAccessURL`** in `FileTreeViewModel` (security review 2026-06-22) — acquired idempotently (once per root, released on root change), and released in `resetState`/`releaseAllAccess`. Don't re-add a `deinit` to release it: Swift 6 forbids a nonisolated `deinit` touching `@MainActor` state, and this single app-lifetime VM only deallocs at process exit. Don't re-introduce per-load `startAccessingSecurityScopedResource` (that was the leak).
- **macOS editor caches the selection as an `NSRange`** (`HighlightingTextView` Coordinator) — it's clamped via `validRange(_:in:)` and cleared via `invalidateCachedRange()` after external text swaps. Keep both: a stale range here was an `NSRangeException` crash on format actions after autosave reload / auto-fix.
- Reset folder picker: now Keychain-backed via `BookmarkStore` (no longer `defaults delete Vera rootFolderBookmark`); use About → "Reset Vera…".
- macOS App Sandbox **re-enabled 2026-06-21** on GA macOS 26.5.1 (the beta pre-main crash is resolved). Entitlements: app-sandbox, user-selected.read-write, files.bookmarks.app-scope, network.client, ubiquity-kvstore.
- **GitHub PAT scopes** (v1.1.0): fine-grained token needs **Contents** (Read to browse, Read+Write to commit / open PRs) and **Metadata**. Token lives in the Keychain (device-local); the repo list syncs via iCloud KVS.
- Minimum OS is **26.4** on both iOS and macOS (the README used to say 18.0 and 15.0).
- VoiceOver testing pending — `accessibilityLabel` added to all icon buttons but never verified with VoiceOver on a real device.
- v1.1.0 GitHub flows (inline browse, open-as-tab, commit/PR/diff, repo sync across devices) ship pending full on-device tap-test with a real Read+Write token.
