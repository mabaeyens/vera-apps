# Privacy Policy — Vera

_Last updated: 2026-06-21_

Vera is built privacy-first, and this policy is short because there is very little to say.

## The short version

- **No account. No sign-up. No tracking. No analytics. No ads.**
- **No servers of ours.** Vera has no backend. There is no "Vera cloud" to send anything to.
- **Your files stay yours.** Vera reads and writes the Markdown files in the folder you
  choose, in your iCloud Drive or on your device. They never pass through us.
- **Open source.** The full source is on GitHub, so you can verify every word of this:
  <https://github.com/mabaeyens/vera-apps>

## What data Vera collects

None. Vera does not collect, transmit, or sell any personal data. We have no way to —
there is no server and no analytics SDK.

## Data that stays on your device

- The folder you pick is remembered via a security-scoped bookmark stored in your device
  **Keychain**.
- Small preferences (font size, linter on/off, focus mode, last-opened files) live in the
  app's local settings.

Both stay on your device and sync only through **your own** iCloud, under your Apple ID —
never to us.

## The only network activity

Vera makes no network calls of its own, with two honest exceptions:

1. **Remote images in your Markdown.** If a file you open references an image by URL
   (`![](https://…)`), Vera fetches that image to display it — exactly like a web browser.
   This goes directly to the image's host, not to us. If you never open such files, this
   never happens.
2. **GitHub (opt-in).** When you connect a repository, Vera talks directly to GitHub's API
   using a fine-grained access token **you** create, stored only in your device Keychain —
   it never syncs anywhere, not even via iCloud. The *list* of repositories you've added
   syncs across your own devices through iCloud's key-value store, under your Apple ID —
   never to us. Nothing is routed through any server of ours.

## Children's privacy

Vera collects no data from anyone, including children.

## Changes

If this policy ever changes, the update will land in this file in the public repository,
with the date above.

## Contact

Questions or concerns: open an issue or discussion at
<https://github.com/mabaeyens/vera-apps>.
