# Contributing

Issues and pull requests are welcome, in Japanese or English.

## The rules that must not break

```
Profile Item → Virtual Candidate → one Choice by Jev → local transform → paste
```

1. **The model makes exactly one choice.** It never generates, edits, shortens, or converts text.
2. **Registered values are never sent anywhere.** Only item names and field context.
3. **No extra yes/no questions to the model** ("should the legal entity be removed?"). Ambiguity is expressed by the
   probability distribution over candidates.
4. New notations or split inputs are supported by **adding a variant** (a deterministic local transform that becomes a candidate).
5. The default experience is **fill first, correct after**. Don't add confirmation steps before filling.

A change that breaks one of these needs a very good reason.

## Setup

macOS 14+, Swift 6 toolchain (Command Line Tools are enough; Xcode is not required), Node 20.6+ for the relay and eval.

```bash
cd macos && swift build && swift run FormFillAISelfTest
cd relay && npm install && npx tsc --noEmit
```

Because there is no Xcode, there is no XCTest and no SwiftData: tests live in the `FormFillAISelfTest` executable, and
persistence is JSON + Keychain.

## Adding a variant

Three places: `ValueVariant.descriptor` (slug, label, description for the model), `ValueTransformer.apply`, and
`SemanticType.allowedVariants`. Return an empty string when the value can't be split — the builder drops empty candidates.
Add checks to `TransformTests.swift` and update the expected candidate count in `CandidateTests.swift`.

## Adding a form field

Add a `Field` to `ProfileTemplate.sections`. **Never rename an existing `label`** — it is the key that matches users' stored
data, and it is what the model reads. The placeholder doubles as an example that every transform must succeed on (tested).

## Changing the prompt

`JevPrompt.instructions` is the single source. After changing it (or labels, or variants), measure:

```bash
python3 eval/build-fixtures.py && AI_GATEWAY_API_KEY=... node eval/run.mjs
```

Please include before/after numbers in the PR.

## Test data

Use obviously fake data (`山田 太郎`, `サンプル商事株式会社`, `03-1234-5678`). Never commit real personal information.
