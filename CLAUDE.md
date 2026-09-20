# FormFillAI

macOS の入力支援アプリ。`Option + Space` で、フォーカス中の入力欄に最適な登録情報を入力する。
人間向けの説明は `README.md` / `README.ja.md`、製品仕様は `docs/SPEC.md`、貢献の手引きは `CONTRIBUTING.md`。

## 崩してはいけない設計

```
Profile Item → Virtual Candidate → Jev Choice → Local Transform → Paste
```

- **Jev にさせるのは 1 回の Choice だけ**。「どの候補を入れるべきか」のみ。
- 文字列の生成・変換（法人格除去、全角化、郵便番号の分割など）はすべてローカルの `ValueTransformer`。
- **登録した値を外へ出さない**。送るのは項目名と表記形式、入力欄の文脈だけ。セルフテストで検証している。
- 「法人格を除くべきか？」のような Boolean 判断を足さない。曖昧さは Choice の確率分布で表す。
- 分割入力や表記違いは **Variant を足して候補として見せる**ことで対応する。Jev に加工させない。
- 体験の既定は「常に自動入力」。最有力の実候補を入れ、違えば `違う` で選び直す。入れる前の確認ステップを増やさない。
- 入力欄ごとに修正を記憶する機能（Correction Rule）は意図的に削除した。同じフォームを繰り返し入力する使い方ではなく、
  複雑さと古い記憶が効くリスクだけが残るため。復活させない。

## 構成

```
macos/Sources/
  FormFillAICore/       UI 非依存のロジック（SwiftUI に依存させない）
    Models/             ProfileItem, VirtualCandidate, SemanticType, ValueVariant, FieldContext
    Profile/            ProfileStore(+Import, +Template), ProfileTemplate, KeychainStore, VirtualCandidateBuilder
      Transform/        ValueTransformer（+Notation / +Split / +Date / +Card）, LegalEntityTables
    Accessibility/      AccessibilityService(+Diagnostics), FocusResolver, FieldContextExtractor,
                        AccessibilityBoost, PasteService
    Classification/     JevPrompt（指示文と回答の読み取り）, JevConnection（経路）, ClassifierClient, OrderedJSON
    Fill/               FillCoordinator, FillState, CandidateRanker, FieldSignature（ログ用）
    Support/            AppSettings, DebugLog, PhaseTimer, AppPaths
  FormFillAI/           メニューバーアプリ本体（App/）と SwiftUI（UI/）
  FormFillAISelfTest/   Xcode 不要の検証用実行ファイル
relay/                  任意の中継サーバー。api/evaluate.ts + lib/{jev,schema,auth,errors}.ts
eval/                   profile.json + build-fixtures.py → cases.json / requests.json、run.mjs
```

## Jev への接続

- **問い合わせの中身は `JevPrompt` だけが作る。** 指示文を経路側（relay など）に置かない。経路で精度が変わってしまう。
- 経路は `JevConnection`: `gateway`（既定・AI Gateway 直結）/ `typesafe`（未検証）/ `relay`（自前の中継）。
  経路ごとの違いは URL・ヘッダ・追加フィールドだけで、`makeRequest` に閉じている。
- AI Gateway 直結のエンドポイント（`/v4/ai/evaluation-model`）は `@ai-sdk/gateway` の内部プロトコル。
  公開ドキュメントに無いので、SDK 更新で変わったら `JevConnection` と `eval/run.mjs` の 2 か所を直す。
- 選択肢の並び（よく使うものが前）に意味があるので、リクエストは `OrderedJSON` で直列化する。`JSONEncoder` や Dictionary に戻さない。

## 登録 UI

登録は **用意済みフォームに値を埋めるだけ**（`ProfileTemplate` + `ProfileFormView`）。
項目名は Jev が入力欄と突き合わせる唯一の手がかりなので、ユーザーに考えさせず、精度の出る名前をこちらで決めておく。

- 欄を増やすときは `ProfileTemplate.sections` に `Field` を足すだけ。**既存の label は変えない**（保存データと突き合わせるキー）。
- 既定セクションは あなた / 会社（住所含む）/ 請求・振込 / 配送先 / 支払い（クレカ）。`isDefault: false`（自宅）は値があるか追加されたときだけ出る。
- **2 つ目以降のセット**は項目名に `セット名：` を前置して表す（`法人カード：クレジットカード番号`）。別テーブルは持たない。
  手がかりが無ければ 1 つ目を選ぶよう指示してあり、`違う` では別セットの同じ項目が先頭に出る（`CandidateRanker.isCounterpart`）。
- `isSensitive` な欄（カード番号など）は、フォームでも候補一覧でも伏せて表示する（`ProfileStore.displayValue`）。
- placeholder は記入例を兼ねる。その通りに入れれば全変換が成立する形にする（セルフテストで検証）。
- 登録上限は 90 件。実際の制約は Jev の 255 択で、`VirtualCandidateBuilder.maxCandidates` が後ろから切り捨てる。

## 変更したら必ず回すもの

```bash
cd macos && swift build && swift run FormFillAISelfTest
cd relay && npx tsc --noEmit
```

- **Variant を足すときに書くのは 3 か所**: `ValueVariant.descriptor`、`ValueTransformer.apply`、`SemanticType.allowedVariants`。
  切り出せない値のときは空文字を返す（候補にならない）。セルフテストの候補総数も更新する。
- 精度に影響しうる変更（項目名、指示文、Variant）の後は `python3 eval/build-fixtures.py && node eval/run.mjs`。
  評価の問い合わせは Swift の本物のコードで組み立てるので、写しの修正は不要。
- テストやドキュメントには実在の個人情報を書かない。ダミー（山田 太郎、サンプル商事株式会社）を使う。

## 環境の制約

- Xcode を前提にしない（Command Line Tools のみ）。**SwiftData と XCTest は使えない**。永続化は JSON + Keychain、テストは `FormFillAISelfTest`。
- ビルドは `macos/scripts/build-app.sh`。自己署名証明書を自動検出して署名する（`CODESIGN_IDENTITY` で上書き可）。
  **アドホック署名だとアクセシビリティ権限が毎回外れる**（TCC は署名でアプリを識別する）。
- `AXUIElement` は CoreFoundation 型。`as? AXUIElement` は常に失敗するので `copyElement` / `copyElements` を使う。
- Chromium / Electron 系は `AXManualAccessibility` を立てるまで中身を公開しない。`AccessibilityBoost` がアプリ前面化のタイミングで立てている。
- 値やキーは Keychain に入るので、コマンドラインから設定するときは署名済みバイナリ経由で行う（`FormFillAI --import` / `--connect`）。
