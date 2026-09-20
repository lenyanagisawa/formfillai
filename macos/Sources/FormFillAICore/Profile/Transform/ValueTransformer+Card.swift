import Foundation

/// クレジットカード: 番号の 4 ボックス分割と、有効期限の表記違い・月/年分割。
extension ValueTransformer {

    /// 16 桁のカード番号を 4 桁ずつに分ける。15 桁（Amex）などは区切り方が違うので候補にしない。
    public static func cardPart(from value: String, index: Int) -> String {
        let digits = Array(value.filter(\.isNumber))
        guard digits.count == 16, (0..<4).contains(index) else { return "" }
        return String(digits[(index * 4)..<(index * 4 + 4)])
    }

    private static let expiryPattern = try! NSRegularExpression(pattern: "^(\\d{1,2})\\D+(\\d{2}|\\d{4})$")

    /// 「01/30」「1/2030」のどちらで登録されていても、各表記と月・年を返す。
    public static func expiryPart(from value: String, variant: ValueVariant) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let groups = captureGroups(of: expiryPattern, in: trimmed),
              let month = Int(groups[0]), (1...12).contains(month), let rawYear = Int(groups[1])
        else { return "" }

        let year4 = rawYear < 100 ? 2000 + rawYear : rawYear
        let mm = String(format: "%02d", month), yy = String(format: "%02d", year4 % 100)
        switch variant {
        case .expiryShort: return "\(mm)/\(yy)"
        case .expiryLong: return "\(mm)/\(year4)"
        case .expiryMonth: return mm
        case .expiryYear2: return yy
        case .expiryYear4: return "\(year4)"
        default: return ""
        }
    }

    /// 画面表示用。末尾 4 文字だけ残して伏せる。
    public static func masked(_ value: String) -> String {
        guard value.count > 4 else { return String(repeating: "•", count: value.count) }
        return String(repeating: "•", count: min(value.count - 4, 12)) + value.suffix(4)
    }
}
