import Foundation

/// ProfileItem.value に ValueVariant を適用して最終入力値を作る。
/// すべてローカル処理。ネットワークも AI も介さない。
///
/// 切り出せない形式のとき（姓名に区切りが無い、和暦の日付など）は空文字を返す。
/// VirtualCandidateBuilder が空の候補を捨てるので、無意味な候補は生まれない。
public enum ValueTransformer {

    public static func apply(_ variant: ValueVariant, to value: String) -> String {
        switch variant {
        case .raw: return value

        case .removeLegalEntity: return removeLegalEntity(from: value)
        case .removeHyphens: return removeHyphens(from: value)
        case .removeWhitespace: return removeWhitespace(from: value)
        case .toFullWidth: return toFullWidth(from: value)
        case .urlWithoutScheme: return removeScheme(from: value)

        case .postalCodeFirst3: return postalCodePart(from: value, first: true)
        case .postalCodeLast4: return postalCodePart(from: value, first: false)
        case .phonePart1: return phonePart(from: value, index: 0)
        case .phonePart2: return phonePart(from: value, index: 1)
        case .phonePart3: return phonePart(from: value, index: 2)
        case .addressPrefecture: return addressPart(from: value, part: .prefecture)
        case .addressCity: return addressPart(from: value, part: .city)
        case .addressAfterCity: return addressPart(from: value, part: .afterCity)
        case .nameFamily, .romanGiven: return namePart(from: value, first: true)
        case .nameGiven, .romanFamily: return namePart(from: value, first: false)
        case .emailLocal: return emailPart(from: value, local: true)
        case .emailDomain: return emailPart(from: value, local: false)

        case .dateSlash, .dateHyphen, .dateKanji, .dateCompact,
             .dateYear, .dateMonth, .dateMonthPadded, .dateDay, .dateDayPadded:
            return datePart(from: value, variant: variant)

        case .cardPart1: return cardPart(from: value, index: 0)
        case .cardPart2: return cardPart(from: value, index: 1)
        case .cardPart3: return cardPart(from: value, index: 2)
        case .cardPart4: return cardPart(from: value, index: 3)
        case .expiryShort, .expiryLong, .expiryMonth, .expiryYear2, .expiryYear4:
            return expiryPart(from: value, variant: variant)
        }
    }
}
