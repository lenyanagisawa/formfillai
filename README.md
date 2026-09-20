# FormFillAI

**Press `⌥ Space` in any text field on your Mac, and the right piece of your information is filled in.**
Built for the quirks of Japanese web forms: furigana, "without 株式会社", full-width only, postal codes split into two boxes, phone numbers split into three.

[日本語の README はこちら](README.ja.md)

```
⌥ Space  →  (tiny spinner)  →  value appears  →  a small [違う / Wrong] button for 4 seconds
```

## How it works

```
Profile Item → Virtual Candidate → one Choice by Jev → local transform → paste
 what you        every notation      "which candidate       deterministic     ⌘A ⌘V
 registered      you might need       fits this field?"     Swift code
```

You register a value once (`サンプル商事株式会社`). FormFillAI derives every notation a form might ask for —
without the legal entity, full-width, split into parts — as *candidates*. When you press the shortcut, it reads the focused
field through the macOS Accessibility API (label, placeholder, nearby text, position among sibling boxes) and asks
[Jev](https://vercel.com/ai-gateway/models/jev), a small decision model, exactly one question: **which candidate belongs here?**

The model never generates or edits text. All transformations are deterministic local code.

| You register | Candidates generated automatically |
| --- | --- |
| `サンプル商事株式会社` | `サンプル商事` |
| `山田 太郎` | `山田太郎` / `山田　太郎` / `山田` / `太郎` |
| `100-0001` | `1000001` / `１００－０００１` / `100` / `0001` |
| `03-1234-5678` | `0312345678` / full-width / `03` / `1234` / `5678` |
| `東京都千代田区千代田1-1 サンプルビル 3F` | full-width / `東京都` / `千代田区` / `千代田1-1 サンプルビル 3F` |
| `1990/01/31` | `1990-01-31` / `1990年1月31日` / `19900131` / `1990` / `1` / `01` / `31` |
| `1234 5678 9012 3456` | no spaces / four 4-digit parts |

## Privacy

**Your registered values never leave your Mac.** This is the core design constraint, not an afterthought.

| Sent to the model | Never sent |
| --- | --- |
| Item *names* and notations (e.g. `会社名フリガナ（法人格を除いた表記）`) | The values you registered — names, addresses, card numbers |
| The focused field's label, placeholder, nearby text, position | Whatever is currently typed in the field |
| App name, window title, page domain and title | Page contents, screenshots |

- Values are stored in the macOS Keychain. API keys too.
- The self-test suite asserts that no registered value appears in the outgoing request (`ProtocolTests.swift`).
- Pasted content is marked with `org.nspasteboard.ConcealedType` so clipboard managers don't record it, and your previous clipboard is restored.
- Card numbers and security codes are masked on screen.
- Password fields are refused.

## Getting started

Requires macOS 14+. Xcode is **not** required — the Command Line Tools are enough.

```bash
git clone https://github.com/lenyanagisawa/formfillai.git
cd formfillai/macos
./scripts/build-app.sh
open build/FormFillAI.app
```

1. Grant **Accessibility** permission when prompted (System Settings → Privacy & Security → Accessibility).
2. Menu bar icon → **登録情報と設定…** → **設定** tab → choose how to reach Jev (below) and paste your key.
3. **登録情報** tab → fill in the fields you expect to need. It saves as you type; empty fields are simply not registered.
4. Put the cursor in any text field and press `⌥ Space`.

> **Code signing matters.** macOS ties the Accessibility permission to the app's code signature. With ad-hoc signing the
> permission is lost on every rebuild. Create a self-signed certificate named `FormFillAI Local Signing`
> (Keychain Access → Certificate Assistant → Create a Certificate… → type: *Code Signing*, then set *Code Signing* to
> *Always Trust*). `build-app.sh` picks it up automatically. Override with `CODESIGN_IDENTITY="…"`.

### Reaching Jev

The question sent to the model is built inside the app, so every route gives the same results.

| Route | What you need | Notes |
| --- | --- | --- |
| **Vercel AI Gateway (direct)** — default | An [AI Gateway API key](https://vercel.com/docs/ai-gateway) | No server to deploy. Fastest (~0.5 s). Uses the endpoint the official SDK uses internally, which is not publicly documented and may change. |
| **Your own relay** | Deploy [`relay/`](relay/) to Vercel | Keeps the API key off the device; share one deployment across a team. ~0.3 s slower. |
| **TypeSafe AI (direct)** | A TypeSafe API key | Implemented from public information; **not verified** against the live API. |

AI Gateway requires a card on file even for the free monthly credit, and the free tier is rate-limited. Jev costs about
$0.04 per million input tokens; one fill is roughly 2–3k tokens.

<details>
<summary>Deploying the relay</summary>

```bash
cd relay
npm install
npx vercel link
npx vercel env add AI_GATEWAY_API_KEY production
npx vercel env add FORMFILLAI_API_TOKEN production   # any long random string
npx vercel deploy --prod
```

Then choose **自前の中継サーバー** in settings and enter `https://<your-app>.vercel.app/api/evaluate` and the token.
The relay holds no prompt and logs no request bodies — it only forwards the question.
</details>

## Accuracy

Measured on 115 cases with ~105 candidates (`eval/`), in "always fill" mode:

- **Correct on the first try: ~95–97%.** The rest are fixed with one click on **違う**.
- Typical misses are notation-level (full-width vs. normal, `MM/YY` vs. `MM/YYYY`), not picking the wrong item.

```bash
python3 eval/build-fixtures.py          # rebuilds requests with the app's real prompt code
AI_GATEWAY_API_KEY=... node eval/run.mjs
```

## Development

```bash
cd macos && swift build && swift run FormFillAISelfTest   # 160+ checks, no Xcode/XCTest needed
cd relay && npx tsc --noEmit
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/SPEC.md](docs/SPEC.md) (Japanese).

## Limitations

- Fields with no accessible label (image-only labels, heavily custom widgets) give the model little to go on.
- Filling **replaces** the whole field (`⌘A` then `⌘V`). If you trigger it in the wrong place, `⌘Z` in that field undoes it.
- Chromium/Electron apps expose their contents only after being asked; the first fill right after launching FormFillAI may take up to ~1.6 s.
- The UI and the prompt are Japanese. English forms work for romanized names and card fields, but this is a tool for Japanese forms first.

## Not affiliated

FormFillAI is an independent project. It is not affiliated with TypeSafe AI or Vercel. "Jev" is TypeSafe AI's model.

## License

[MIT](LICENSE)
