# Security Policy

FormFillAI handles personal data — names, addresses, bank and card details — so reports are taken seriously.

## Reporting a vulnerability

Please **do not open a public issue**. Use GitHub's private reporting instead:
**Security → Report a vulnerability** on this repository.

Include what you found, how to reproduce it, and what an attacker could gain. You should get a reply within a week.

## What counts

- Any path by which a **registered value** leaves the device (network, logs, files other than the Keychain).
- The relay accepting unauthenticated requests, or logging request contents.
- Filling a password field, or filling without the user pressing the shortcut.
- Pasted values being retained on the clipboard or recorded where they shouldn't be.

## Design guarantees worth checking

- The request sent to the model is built in `JevPrompt.request`. It contains item *names* and field context only.
  `ProtocolTests.swift` asserts no registered value appears in it.
- Values and API keys are stored in the macOS Keychain (`KeychainStore.swift`). Metadata (labels, types) is stored as JSON in
  `~/Library/Application Support/FormFillAI/`.
- The local debug log is off by default and never contains values.

## Known trade-offs

- Filling uses the clipboard (`⌘A`, `⌘V`) so that web frameworks see a real input event. The value is on the clipboard for
  ~300 ms, marked `org.nspasteboard.ConcealedType`. Clipboard managers that ignore that convention may still record it.
- The Accessibility permission is broad by nature. FormFillAI reads the focused field's attributes and nearby static text, not its value.
