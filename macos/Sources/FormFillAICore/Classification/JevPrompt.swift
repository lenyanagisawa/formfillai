import Foundation

/// 判断モデル（Jev / Clef）への問い合わせ内容を組み立て、回答を読み解く。
///
/// 指示文はここ 1 か所にだけ置く。どの経路（AI Gateway 直結 / TypeSafe 直結 / 自前の中継サーバー）で
/// 呼んでも同じ問い合わせになるので、経路によってモデルへの指示が変わらない。
///
/// Jev にさせるのは「用意された候補のうちどれを入れるか」の選択 1 回だけ。
/// 文字列の生成・変換は一切させず、登録された値も渡さない。
public enum JevPrompt {

    /// 候補の説明の書き方。モデルによって効く書き方が違うので、経路ごとに計測した方を使う。
    ///
    /// Jev は項目名だけで「分割されていない欄には項目全体を選ぶ」という指示に従える（実測 97.1%）。
    /// Clef は従いにくく、通常の欄でも「姓だけ」「市外局番だけ」を選んでしまう。
    /// 候補そのものに役割を書くと 77.1% → 87.2% に改善した（clef）。
    public enum CandidateStyle: Sendable {
        case plain
        case annotated

        func describe(_ candidate: VirtualCandidate) -> String {
            switch self {
            case .plain:
                return candidate.criteria
            case .annotated:
                return candidate.variant == .raw
                    ? "\(candidate.criteria)（項目全体。通常の入力欄にはこれを選ぶ）"
                    : "【分割・表記指定の欄専用】\(candidate.criteria)"
            }
        }
    }

    public static let questionKey = "field"
    /// 「該当なし」の選択肢。アプリ内部では `VirtualCandidate.noneId` として扱う。
    public static let noneOptionKey = "none_of_the_above"

    public static let instructions = [
        "現在フォーカスされている入力欄に、どの候補を入力するべきかを選んでください。",
        "入力欄の label、placeholder、周辺テキスト、ページやウィンドウのタイトルを理解し、最も適切な候補を1つ選択してください。",
        "入力欄が指定する表記形式も考慮してください。例:「株式会社等を除く」「ハイフンなし」「スペースなし」「全角で」「カタカナで」。",
        "入力欄が複数のボックスに分割されていることがあります（姓と名、セイとメイ、郵便番号が2つ、電話番号が3つ、年・月・日、メールアドレスの@前後、カード番号が4つ、住所が都道府県・市区町村・番地以降など）。",
        "field.positionHint（同種の入力欄が並ぶ中での位置）を手がかりに、分割されたどの部分を入れる欄かを判断してください。「3つのうち2番目（中央）」なら、3分割の真ん中の部分（電話番号の市内局番、年月日の月）です。",
        "例: 「2つのうち1番目」の郵便番号欄なら「前3桁」、「2つのうち2番目」なら「後4桁」。",
        "分割されていない通常の入力欄（positionHint が無い、またはラベルが項目全体を指している）では、分割された一部ではなく項目全体の候補を選んでください。",
        "入力欄のラベルやページが英語の場合は、ローマ字・英語表記の候補を優先してください。",
        "「法人カード：クレジットカード番号」のように「名前：」で始まる候補は、同じ種類の情報の2つ目以降のセットです。入力欄・ページ・周辺テキストにその名前を示す手がかりがある場合だけ選び、手がかりが無ければ「名前：」の付かない候補（1つ目のセット）を選んでください。",
        "候補に存在しない変換を推測・生成してはいけません。候補として提示された表記の中から選ぶだけです。",
        "該当する候補がない場合は \(noneOptionKey) を選択してください。",
    ].joined(separator: "\n")

    // MARK: - リクエスト

    /// `{ "state": …, "questions": { "field": { type, instructions, criteria } } }`
    public static func request(
        context: FieldContext,
        candidates: [VirtualCandidate],
        style: CandidateStyle = .plain
    ) -> OrderedJSON {
        var criteria = candidates.map { (key: $0.id, value: OrderedJSON.string(style.describe($0))) }
        criteria.append((noneOptionKey, .string("上記のどの登録情報も、この入力欄には当てはまらない")))

        return .object([
            ("state", state(from: context)),
            ("questions", .object([
                (questionKey, .object([
                    ("type", .string("choice")),
                    ("instructions", .string(instructions)),
                    ("criteria", .object(criteria)),
                ])),
            ])),
        ])
    }

    /// 入力欄の状況。現在入力されている値は含めない。
    static func state(from context: FieldContext) -> OrderedJSON {
        let field = context.field
        var fieldPairs: [(key: String, value: OrderedJSON)] = [
            ("role", .optional(field.role)),
            ("title", .optional(field.title)),
            ("placeholder", .optional(field.placeholder)),
            ("description", .optional(field.description)),
            ("help", .optional(field.help)),
            ("nearbyTexts", .array(field.nearbyTexts.map(OrderedJSON.string))),
        ]
        if let hint = positionHint(index: field.siblingIndex, count: field.siblingCount) {
            fieldPairs.append(("positionHint", .string(hint)))
        }

        var pairs: [(key: String, value: OrderedJSON)] = [
            ("application", .object([
                ("name", .optional(context.application.name)),
                ("bundleId", .optional(context.application.bundleId)),
            ])),
            ("window", .object([("title", .optional(context.window.title))])),
        ]
        if let page = context.page {
            pairs.append(("page", .object([("domain", .optional(page.domain)), ("title", .optional(page.title))])))
        }
        pairs.append(("field", .object(fieldPairs)))
        return .object(pairs)
    }

    /// 数値のままだと「3つのうち2番目」を取り違えやすいので、言葉にして渡す。
    public static func positionHint(index: Int?, count: Int?) -> String? {
        guard let index, let count, count >= 2, (1...count).contains(index) else { return nil }
        let place = index == 1 ? "先頭" : index == count ? "末尾" : "中央"
        return "同じ種類の入力欄が\(count)つ並んでいるうちの\(index)番目（\(place)）"
    }

    // MARK: - レスポンス

    private struct Response: Decodable {
        struct Answer: Decodable {
            let choice: String
            let probabilities: [String: Double]?
            /// Clef は答えの中に確信度を入れる。
            let confidence: Double?
        }
        struct ProviderMetadata: Decodable {
            struct TypeSafe: Decodable { let confidence: [String: Double]? }
            let typesafe: TypeSafe?
        }
        let answers: [String: Answer]
        /// Jev（AI Gateway）は providerMetadata の側に確信度を入れる。
        let providerMetadata: ProviderMetadata?
    }

    /// Cloudflare の REST API は本体を `result` で包む。包まれていればほどく。
    private struct CloudflareEnvelope: Decodable { let result: Response }

    public enum ParseError: LocalizedError {
        case missingAnswer
        public var errorDescription: String? { "Jev の回答を解釈できませんでした" }
    }

    /// 経路によらず共通の `{ answers, providerMetadata? }` を読む。
    public static func parse(_ data: Data) throws -> ClassificationResult {
        let decoder = JSONDecoder()
        let response = (try? decoder.decode(Response.self, from: data))
            ?? (try? decoder.decode(CloudflareEnvelope.self, from: data).result)
        guard let response, let answer = response.answers[questionKey] else { throw ParseError.missingAnswer }

        func candidateId(_ key: String) -> String { key == noneOptionKey ? VirtualCandidate.noneId : key }

        let alternatives = (answer.probabilities ?? [:])
            .filter { $0.value > 0.001 }
            .map { ClassificationResult.Alternative(candidateId: candidateId($0.key), probability: $0.value) }
            .sorted { $0.probability > $1.probability }

        return ClassificationResult(
            selectedCandidateId: candidateId(answer.choice),
            // 分布が返らなければ確率不明として 0。しきい値方式では自動入力されない。
            selectedProbability: answer.probabilities?[answer.choice] ?? 0,
            choiceConfidence: answer.confidence ?? response.providerMetadata?.typesafe?.confidence?[questionKey],
            alternatives: Array(alternatives.prefix(8))
        )
    }
}
