# Vera — Backlog

## Open bugs

*(none)*

---

## Pending

- **PrivacyInfo.xcprivacy** — file created at `Vera/Vera/PrivacyInfo.xcprivacy`; must be dragged into the Vera target in Xcode to be bundled (I2)
- **Keychain for bookmark** — move `rootFolderBookmark` from `UserDefaults` to Keychain (`kSecClassGenericPassword`); low urgency while macOS sandbox is off (M2)
- **Re-enable macOS App Sandbox** — blocked on macOS 26 beta crash upstream (M1)

---

## Won't fix

- **`^1` footnote/superscript in Atlas** — cannot be delivered
- **Animated V icon** — dropped

---

## Notes

- Reset folder picker: `defaults delete Vera rootFolderBookmark`
- macOS App Sandbox intentionally disabled — causes pre-main crash on macOS 26 beta (CLAUDE.md constraint)
- VoiceOver testing pending — `accessibilityLabel` added to all icon buttons but never verified with VoiceOver on a real device
