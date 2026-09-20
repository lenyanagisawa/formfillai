import Foundation

/// 登録項目の意味的な種別。
/// Virtual Candidate をどう生成するかを決めるためだけに使う。
public enum SemanticType: String, Codable, CaseIterable, Sendable {
    case personName
    case personNameKana
    case personNameRoman

    case companyName
    case companyNameKana

    case postalCode
    case phoneNumber

    case email
    case address

    case jobTitle
    case department

    case websiteURL
    case date

    case creditCardNumber
    case cardExpiry

    case custom

    /// プリセット選択時に既定で入る項目名。
    public var defaultLabel: String {
        switch self {
        case .personName: return "氏名"
        case .personNameKana: return "氏名カナ"
        case .personNameRoman: return "氏名（ローマ字）"
        case .companyName: return "会社名"
        case .companyNameKana: return "会社名フリガナ"
        case .postalCode: return "郵便番号"
        case .phoneNumber: return "電話番号"
        case .email: return "メールアドレス"
        case .address: return "住所"
        case .jobTitle: return "役職"
        case .department: return "部署"
        case .websiteURL: return "Webサイト"
        case .date: return "日付（生年月日など）"
        case .creditCardNumber: return "クレジットカード番号"
        case .cardExpiry: return "カード有効期限"
        case .custom: return "その他"
        }
    }

    /// Profile Editor のプリセット一覧。
    public static var presets: [SemanticType] {
        [.companyName, .companyNameKana, .personName, .personNameKana, .personNameRoman,
         .email, .phoneNumber, .postalCode, .address,
         .jobTitle, .department, .websiteURL, .date, .creditCardNumber, .cardExpiry, .custom]
    }

    /// Jev へ渡す候補 ID に使う ASCII スラッグ。
    public var slug: String {
        switch self {
        case .personName: return "person_name"
        case .personNameKana: return "person_name_kana"
        case .personNameRoman: return "person_name_roman"
        case .companyName: return "company_name"
        case .companyNameKana: return "company_name_kana"
        case .postalCode: return "postal_code"
        case .phoneNumber: return "phone_number"
        case .email: return "email"
        case .address: return "address"
        case .jobTitle: return "job_title"
        case .department: return "department"
        case .websiteURL: return "website_url"
        case .date: return "date"
        case .creditCardNumber: return "card_number"
        case .cardExpiry: return "card_expiry"
        case .custom: return "custom"
        }
    }

    /// この種別で生成して意味のある Variant だけを返す。
    /// ここに無い変換は Virtual Candidate として作らない。
    ///
    /// 日本のフォームは 1 つの情報を複数の入力欄に分けることが多い（姓/名、郵便番号 2 ボックス、
    /// 電話 3 ボックス、年/月/日、メールの @ 前後）。分割された各部分も候補として用意しておく。
    /// 画面に値をそのまま出してはいけない種類。フォームや候補一覧ではマスクして表示する。
    public var isSensitive: Bool { self == .creditCardNumber }

    public var allowedVariants: [ValueVariant] {
        switch self {
        case .companyName, .companyNameKana:
            return [.raw, .removeLegalEntity]
        case .personName, .personNameKana:
            return [.raw, .removeWhitespace, .toFullWidth, .nameFamily, .nameGiven]
        case .personNameRoman:
            // 「First Last」の順で登録する前提。
            return [.raw, .romanGiven, .romanFamily]
        case .postalCode:
            return [.raw, .removeHyphens, .toFullWidth, .postalCodeFirst3, .postalCodeLast4]
        case .phoneNumber:
            return [.raw, .removeHyphens, .toFullWidth, .phonePart1, .phonePart2, .phonePart3]
        case .address:
            // 番地の数字やビル名の英字が半角のままだと弾かれるフォームがある。
            return [.raw, .toFullWidth, .addressPrefecture, .addressCity, .addressAfterCity]
        case .email:
            return [.raw, .emailLocal, .emailDomain]
        case .websiteURL:
            return [.raw, .urlWithoutScheme]
        case .date:
            return [.raw, .dateSlash, .dateHyphen, .dateKanji, .dateCompact,
                    .dateYear, .dateMonth, .dateMonthPadded, .dateDay, .dateDayPadded]
        case .creditCardNumber:
            // 「1234 5678 9012 3456」と 4 桁ごとに区切って登録する前提。
            return [.raw, .removeWhitespace, .cardPart1, .cardPart2, .cardPart3, .cardPart4]
        case .cardExpiry:
            return [.raw, .expiryShort, .expiryLong, .expiryMonth, .expiryYear2, .expiryYear4]
        case .jobTitle, .department, .custom:
            // 分割や表記違いの慣習が無い項目。無意味な候補を作らない。
            return [.raw]
        }
    }
}
