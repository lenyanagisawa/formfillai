import Foundation

/// あらかじめ用意した登録フォームの定義。
///
/// 項目名は Jev が入力欄と突き合わせる唯一の手がかりなので、精度が出る名前をこちらで決めておく。
/// ユーザーは値を埋めるだけでよく、「種類」や「項目名の付け方」を考えなくて済む。
public enum ProfileTemplate {

    public struct Field: Identifiable, Sendable {
        /// 登録時の項目名。Profile Item の label と一致させて突き合わせる。
        public let label: String
        /// フォーム上の短い表示名。
        public let title: String
        public let semanticType: SemanticType
        public let placeholder: String
        /// 登録のしかたで結果が変わるときだけ書く。
        public let hint: String?
        /// 入力中以外は伏せて表示する（カード番号、セキュリティコード）。
        public let isSensitive: Bool

        public var id: String { label }

        /// 2 つ目以降のセット用に、項目名へセット名を付けた写しを作る。
        /// 例: 「クレジットカード番号」→「法人カード：クレジットカード番号」
        public func scoped(to setName: String) -> Field {
            Field(ProfileTemplate.scopedLabel(label, setName: setName), title: title, semanticType,
                  placeholder: placeholder, hint: hint, sensitive: isSensitive)
        }

        init(_ label: String, title: String? = nil, _ semanticType: SemanticType,
             placeholder: String, hint: String? = nil, sensitive: Bool = false) {
            self.label = label
            self.title = title ?? label
            self.semanticType = semanticType
            self.placeholder = placeholder
            self.hint = hint
            self.isSensitive = sensitive || semanticType.isSensitive
        }
    }

    public struct Section: Identifiable, Sendable {
        public let title: String
        /// 2 つ目以降のセットに付ける名前の例。
        public var setNameExample = "2つ目"
        public let symbol: String
        public let fields: [Field]
        /// false のセクションは、値が入っているか、ユーザーが追加したときだけ表示する。
        public var isDefault = true
        public var id: String { title }
    }

    private static let hyphenHint = "ハイフン付きで入力（なし・全角・分割は自動で用意されます）"
    private static let fullAddressHint = "都道府県から建物名まで続けて入力（都道府県・市区町村・番地以降は自動で切り出されます）"
    private static let streetHint = "番地と建物名が別の欄になっているフォーム用"

    public static let sections: [Section] = [
        Section(title: "あなた", setNameExample: "家族", symbol: "person", fields: [
            Field("氏名", .personName, placeholder: "山田 太郎", hint: "姓と名の間にスペース（姓・名の分割に使います）"),
            Field("氏名カナ", .personNameKana, placeholder: "ヤマダ タロウ", hint: "セイとメイの間にスペース"),
            Field("氏名（ローマ字）", .personNameRoman, placeholder: "Taro Yamada", hint: "名 → 姓の順"),
            Field("氏名（ローマ字・大文字）", .personNameRoman, placeholder: "TARO YAMADA"),
            Field("生年月日", .date, placeholder: "1990/01/31", hint: "西暦で入力（表記違いと年・月・日は自動で用意されます）"),
            Field("携帯番号", .phoneNumber, placeholder: "090-1234-5678", hint: hyphenHint),
            Field("個人 メールアドレス", title: "個人のメールアドレス", .email, placeholder: "taro@example.com"),
        ]),
        Section(title: "会社", setNameExample: "2社目の社名", symbol: "building.2", fields: [
            Field("会社名", .companyName, placeholder: "サンプル商事株式会社", hint: "法人格を含めた正式名称（法人格なしは自動で用意されます）"),
            Field("会社名フリガナ", .companyNameKana, placeholder: "サンプルショウジカブシキガイシャ", hint: "カブシキガイシャまで含める"),
            Field("会社名（英語）", .custom, placeholder: "Sample Trading, Inc."),
            Field("役職", .jobTitle, placeholder: "代表取締役"),
            Field("部署", .department, placeholder: "営業部"),
            Field("仕事 メールアドレス", title: "仕事のメールアドレス", .email, placeholder: "taro@example.co.jp"),
            Field("会社 電話番号", title: "電話番号", .phoneNumber, placeholder: "03-1234-5678", hint: hyphenHint),
            Field("会社 FAX番号", title: "FAX番号", .phoneNumber, placeholder: "03-1234-5679"),
            Field("会社サイトURL", .websiteURL, placeholder: "https://example.co.jp/"),
            Field("サービスサイトURL", .websiteURL, placeholder: "https://service.example.jp/"),
            Field("設立年月日", .date, placeholder: "2020/04/01"),
            Field("会社 郵便番号", title: "郵便番号", .postalCode, placeholder: "100-0001", hint: hyphenHint),
            Field("会社 住所", title: "住所", .address, placeholder: "東京都千代田区千代田1-1 サンプルビル 3F", hint: fullAddressHint),
            Field("会社 住所（町名・番地）", title: "町名・番地のみ", .address, placeholder: "千代田1-1", hint: streetHint),
            Field("会社 住所（建物名・階）", title: "建物名・階のみ", .address, placeholder: "サンプルビル 3F"),
            Field("会社 住所（英語）", title: "住所（英語）", .custom, placeholder: "3F Sample Bldg., 1-1 Chiyoda, Chiyoda-ku, Tokyo"),
        ]),
        Section(title: "請求・振込", setNameExample: "別口座", symbol: "yensign.circle", fields: [
            Field("法人番号", .custom, placeholder: "1234567890123", hint: "13桁"),
            Field("インボイス登録番号", .custom, placeholder: "T1234567890123", hint: "T から入力"),
            Field("振込先 銀行名", title: "銀行名", .custom, placeholder: "◯◯銀行"),
            Field("振込先 支店名", title: "支店名", .custom, placeholder: "◯◯支店"),
            Field("振込先 口座種別", title: "口座種別", .custom, placeholder: "普通"),
            Field("振込先 口座番号", title: "口座番号", .custom, placeholder: "1234567"),
            Field("振込先 口座名義（カナ）", title: "口座名義（カナ）", .custom, placeholder: "サンプルショウジ（カ"),
        ]),
        Section(title: "配送先", setNameExample: "倉庫", symbol: "shippingbox", fields: [
            Field("配送先 郵便番号", title: "郵便番号", .postalCode, placeholder: "107-0062", hint: hyphenHint),
            Field("配送先 住所", title: "住所", .address, placeholder: "東京都港区南青山1-1-1 サンプルビル 6F", hint: fullAddressHint),
            Field("配送先 住所（町名・番地）", title: "町名・番地のみ", .address, placeholder: "南青山1-1-1", hint: streetHint),
            Field("配送先 住所（建物名・階）", title: "建物名・階のみ", .address, placeholder: "サンプルビル 6F"),
        ]),
        Section(title: "支払い（クレジットカード）", setNameExample: "法人カード", symbol: "creditcard", fields: [
            Field("クレジットカード番号", title: "カード番号", .creditCardNumber, placeholder: "1234 5678 9012 3456",
                  hint: "4桁ごとにスペース（スペースなしと4分割は自動で用意されます）"),
            Field("カード名義", .custom, placeholder: "TARO YAMADA", hint: "カードに刻印されているとおりに"),
            Field("カード有効期限", title: "有効期限", .cardExpiry, placeholder: "01/30", hint: "月/年（表記違いと月・年の分割は自動で用意されます）"),
            Field("カード セキュリティコード", title: "セキュリティコード", .custom, placeholder: "123",
                  hint: "空欄のままでも構いません（都度入力したい場合）", sensitive: true),
        ]),
        Section(title: "自宅", setNameExample: "実家", symbol: "house", fields: [
            Field("自宅 郵便番号", title: "郵便番号", .postalCode, placeholder: "150-0001", hint: hyphenHint),
            Field("自宅 住所", title: "住所", .address, placeholder: "東京都渋谷区神宮前1-1-1 サンプル荘 101", hint: fullAddressHint),
            Field("自宅 住所（町名・番地）", title: "町名・番地のみ", .address, placeholder: "神宮前1-1-1", hint: streetHint),
            Field("自宅 住所（建物名・部屋番号）", title: "建物名・部屋番号のみ", .address, placeholder: "サンプル荘 101"),
        ], isDefault: false),
    ]

    public static let allFields: [Field] = sections.flatMap(\.fields)
    private static let fieldsByLabel = Dictionary(uniqueKeysWithValues: allFields.map { ($0.label, $0) })
    private static let sectionByLabel: [String: Section] = Dictionary(
        uniqueKeysWithValues: sections.flatMap { section in section.fields.map { ($0.label, section) } }
    )

    // MARK: - 2 つ目以降のセット

    /// セット名と項目名の区切り。項目名には使われない文字にしている。
    public static let setSeparator: Character = "："

    public static func scopedLabel(_ label: String, setName: String) -> String {
        "\(setName)\(setSeparator)\(label)"
    }

    /// 「法人カード：クレジットカード番号」→（法人カード, クレジットカード番号の欄, 支払いセクション）。
    /// フォームの欄に対応しない項目名なら nil。
    public static func parseScoped(_ label: String) -> (setName: String, field: Field, section: Section)? {
        guard let index = label.firstIndex(of: setSeparator) else { return nil }
        let setName = String(label[..<index])
        let base = String(label[label.index(after: index)...])
        guard !setName.isEmpty, let field = fieldsByLabel[base], let section = sectionByLabel[base] else { return nil }
        return (setName, field, section)
    }

    /// 登録済みの項目から、セクションごとの追加セット名を登場順に拾う。
    public static func extraSetNames(in items: [ProfileItem]) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for item in items {
            guard let parsed = parseScoped(item.label) else { continue }
            if !(result[parsed.section.id] ?? []).contains(parsed.setName) {
                result[parsed.section.id, default: []].append(parsed.setName)
            }
        }
        return result
    }

    /// フォームに無い、ユーザーが自分で足した項目かどうか。
    public static func isCustom(_ item: ProfileItem) -> Bool {
        fieldsByLabel[item.label] == nil && parseScoped(item.label) == nil
    }

    /// 項目名から、画面で伏せるべきかを引く。
    public static func isSensitive(label: String) -> Bool {
        (fieldsByLabel[label] ?? parseScoped(label)?.field)?.isSensitive ?? false
    }

    /// 並び順のキー: 1 つ目のセット → 追加セット（セクション順・登場順）→ 自分で足した項目。
    static func orderKey(for label: String, extraSets: [String: [String]]) -> (Int, Int, Int)? {
        let fieldIndex = Dictionary(uniqueKeysWithValues: allFields.enumerated().map { ($1.label, $0) })
        if let index = fieldIndex[label] { return (0, 0, index) }
        guard let parsed = parseScoped(label), let index = fieldIndex[parsed.field.label] else { return nil }
        let setIndex = extraSets[parsed.section.id]?.firstIndex(of: parsed.setName) ?? 0
        return (1, setIndex, index)
    }
}
