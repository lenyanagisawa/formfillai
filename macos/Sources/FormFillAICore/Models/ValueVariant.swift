import Foundation

/// Profile Item の value に適用する決定論的な表示変換。
/// 変換は 100% ローカルで行い、Jev には一切変換をさせない。
///
/// Variant を足すときは、ここの `descriptor` と `ValueTransformer.apply`、
/// `SemanticType.allowedVariants` の 3 か所を書く。評価用フィクスチャは
/// `swift run FormFillAISelfTest --dump-variants` の出力から作られるので、写しを直す必要はない。
public enum ValueVariant: String, Codable, CaseIterable, Sendable {
    case raw

    // 表記違い
    case removeLegalEntity
    case removeHyphens
    case removeWhitespace
    case toFullWidth
    case urlWithoutScheme

    // 分割入力（1 つの情報が複数の入力欄に分かれているフォーム）
    case postalCodeFirst3, postalCodeLast4
    case phonePart1, phonePart2, phonePart3
    case addressPrefecture, addressCity, addressAfterCity
    case nameFamily, nameGiven
    case romanGiven, romanFamily
    case emailLocal, emailDomain

    // 日付の表記違いと年月日の分割
    case dateSlash, dateHyphen, dateKanji, dateCompact
    case dateYear, dateMonth, dateMonthPadded, dateDay, dateDayPadded

    // クレジットカード: 番号の 4 ボックス分割と、有効期限の表記違い・月/年分割
    case cardPart1, cardPart2, cardPart3, cardPart4
    case expiryShort, expiryLong, expiryMonth, expiryYear2, expiryYear4

    public struct Descriptor: Sendable {
        /// 候補 ID に使う ASCII スラッグ。
        public let slug: String
        /// UI に出す短い注記。例:「会社名（法人格なし）」の括弧内。
        public let label: String
        /// Jev へ渡す、より具体的な説明。
        public let criteria: String
    }

    /// raw には注記が無い。
    public var descriptor: Descriptor? {
        switch self {
        case .raw: return nil

        case .removeLegalEntity:
            return .init(slug: "no_legal_entity", label: "法人格なし",
                         criteria: "株式会社・合同会社などの法人格を除いた表記")
        case .removeHyphens:
            return .init(slug: "no_hyphen", label: "ハイフンなし", criteria: "ハイフンを除いた数字のみの表記")
        case .removeWhitespace:
            return .init(slug: "no_space", label: "スペースなし", criteria: "スペースを除いて詰めた表記")
        case .toFullWidth:
            return .init(slug: "full_width", label: "全角", criteria: "数字・英字・記号をすべて全角にした表記")
        case .urlWithoutScheme:
            return .init(slug: "no_scheme", label: "https://なし",
                         criteria: "https:// を除いた表記。入力欄の前に https:// が固定表示されている場合")

        case .postalCodeFirst3:
            return .init(slug: "zip_first3", label: "前3桁",
                         criteria: "郵便番号の前半3桁。入力欄が2つに分かれている場合の1つ目")
        case .postalCodeLast4:
            return .init(slug: "zip_last4", label: "後4桁",
                         criteria: "郵便番号の後半4桁。入力欄が2つに分かれている場合の2つ目")
        case .phonePart1:
            return .init(slug: "tel_part1", label: "市外局番",
                         criteria: "電話番号の市外局番。入力欄が3つに分かれている場合の1つ目")
        case .phonePart2:
            return .init(slug: "tel_part2", label: "市内局番",
                         criteria: "電話番号の市内局番。入力欄が3つに分かれている場合の2つ目")
        case .phonePart3:
            return .init(slug: "tel_part3", label: "加入者番号",
                         criteria: "電話番号の加入者番号。入力欄が3つに分かれている場合の3つ目")
        case .addressPrefecture:
            return .init(slug: "pref", label: "都道府県", criteria: "住所のうち都道府県だけ")
        case .addressCity:
            return .init(slug: "city", label: "市区町村", criteria: "住所のうち市区町村だけ")
        case .addressAfterCity:
            return .init(slug: "after_city", label: "番地以降",
                         criteria: "住所のうち市区町村より後ろ（番地以降。建物名も含む）")
        case .nameFamily:
            return .init(slug: "family", label: "姓",
                         criteria: "姓（苗字）だけ。姓と名で入力欄が分かれている場合の1つ目")
        case .nameGiven:
            return .init(slug: "given", label: "名",
                         criteria: "名（下の名前）だけ。姓と名で入力欄が分かれている場合の2つ目")
        case .romanGiven:
            return .init(slug: "roman_given", label: "First name",
                         criteria: "ローマ字の名だけ（First name / Given name）")
        case .romanFamily:
            return .init(slug: "roman_family", label: "Last name",
                         criteria: "ローマ字の姓だけ（Last name / Family name / Surname）")
        case .emailLocal:
            return .init(slug: "email_local", label: "@より前",
                         criteria: "メールアドレスの @ より前だけ。入力欄が @ で2つに分かれている場合の1つ目")
        case .emailDomain:
            return .init(slug: "email_domain", label: "@より後",
                         criteria: "メールアドレスの @ より後ろ（ドメイン）だけ。入力欄が @ で2つに分かれている場合の2つ目")

        case .dateSlash:
            return .init(slug: "date_slash", label: "2000/01/31 形式", criteria: "2000/01/31 のようなスラッシュ区切りの表記")
        case .dateHyphen:
            return .init(slug: "date_hyphen", label: "2000-01-31 形式", criteria: "2000-01-31 のようなハイフン区切りの表記")
        case .dateKanji:
            return .init(slug: "date_kanji", label: "2000年1月31日 形式", criteria: "2000年1月31日 のような漢字の表記")
        case .dateCompact:
            return .init(slug: "date_compact", label: "20000131 形式", criteria: "20000131 のような区切りなし8桁の表記")
        case .dateYear:
            return .init(slug: "year", label: "年", criteria: "西暦の年だけ。年・月・日で入力欄が分かれている場合の1つ目")
        case .dateMonth:
            return .init(slug: "month", label: "月", criteria: "月だけ。年・月・日で入力欄が分かれている場合の2つ目")
        case .dateMonthPadded:
            return .init(slug: "month_padded", label: "月・2桁", criteria: "月だけ、2桁のゼロ埋め（01〜12）")
        case .dateDay:
            return .init(slug: "day", label: "日", criteria: "日だけ。年・月・日で入力欄が分かれている場合の3つ目")
        case .dateDayPadded:
            return .init(slug: "day_padded", label: "日・2桁", criteria: "日だけ、2桁のゼロ埋め（01〜31）")

        case .cardPart1: return Self.cardPart(1)
        case .cardPart2: return Self.cardPart(2)
        case .cardPart3: return Self.cardPart(3)
        case .cardPart4: return Self.cardPart(4)
        case .expiryShort:
            return .init(slug: "exp_short", label: "MM/YY", criteria: "有効期限を 01/30 のように 月/年2桁 で書いた表記")
        case .expiryLong:
            return .init(slug: "exp_long", label: "MM/YYYY", criteria: "有効期限を 01/2030 のように 月/年4桁 で書いた表記")
        case .expiryMonth:
            return .init(slug: "exp_month", label: "月", criteria: "有効期限の月だけ（2桁）。月と年で入力欄が分かれている場合の1つ目")
        case .expiryYear2:
            return .init(slug: "exp_year2", label: "年・2桁", criteria: "有効期限の年だけ、下2桁。月と年で入力欄が分かれている場合の2つ目")
        case .expiryYear4:
            return .init(slug: "exp_year4", label: "年・4桁", criteria: "有効期限の年だけ、西暦4桁")
        }
    }

    private static func cardPart(_ n: Int) -> Descriptor {
        .init(slug: "card_part\(n)", label: "\(n)つ目の4桁",
              criteria: "カード番号を4桁ずつ区切った\(n)つ目。入力欄が4つに分かれている場合の\(n)番目")
    }

    public var slug: String { descriptor?.slug ?? "raw" }
    public var labelSuffix: String? { descriptor?.label }
    public var criteriaSuffix: String? { descriptor?.criteria }
}
