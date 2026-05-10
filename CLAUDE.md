# CLAUDE.md — Vera

**Core premise:** Vera browses and edits any `.md` file anywhere in the user's iCloud Drive or local storage. No vault, no container, no project folder. The user's file system is the data model.

See `PROJECT.md` for identity, architecture, and key decisions. See `BACKLOG.md` for phase status, upcoming work, bugs, and notes.

---

## Safety rules

- Never delete files, branches, or the repository without explicit approval.
- Never commit API keys or secrets.
- `git pull origin main` before every commit or push.
- All GitHub operations use `gh` at `/opt/homebrew/bin/gh`.

---

## Coding conventions

- `@MainActor` on all ViewModels (Swift 6).
- `async/await` for all file I/O; wrap `FileManager` calls in `Task`.
- No force-unwraps in production paths.
- No App Sandbox on macOS target — causes pre-main crash on macOS 26 beta.
- Bundle ID: `com.mab.Vera` — UserDefaults domain is `Vera` (not `com.mab.Vera`).
- Separate entitlements: `Vera-iOS.entitlements` and `Vera-macOS.entitlements`.

---

## Build commands

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
