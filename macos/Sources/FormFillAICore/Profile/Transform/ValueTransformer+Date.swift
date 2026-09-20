import Foundation

/// 日付の表記違いと、年・月・日の分割。
extension ValueTransformer {

    private static let datePatterns = [
        try! NSRegularExpression(pattern: "^(\\d{4})(\\d{2})(\\d{2})$"),               // 19900131
        try! NSRegularExpression(pattern: "^(\\d{4})\\D+(\\d{1,2})\\D+(\\d{1,2})\\D*$"), // 1990/1/31, 1990年1月31日
    ]

    /// 登録された日付を読み取り、指定の表記や年・月・日の一部を返す。
    /// 西暦として読めないもの（和暦など）は候補にしない。
    public static func datePart(from value: String, variant: ValueVariant) -> String {
        guard let (year, month, day) = parseDate(value) else { return "" }
        let mm = String(format: "%02d", month), dd = String(format: "%02d", day)
        switch variant {
        case .dateSlash: return "\(year)/\(mm)/\(dd)"
        case .dateHyphen: return "\(year)-\(mm)-\(dd)"
        case .dateKanji: return "\(year)年\(month)月\(day)日"
        case .dateCompact: return "\(year)\(mm)\(dd)"
        case .dateYear: return "\(year)"
        case .dateMonth: return "\(month)"
        case .dateMonthPadded: return mm
        case .dateDay: return "\(day)"
        case .dateDayPadded: return dd
        default: return ""
        }
    }

    static func parseDate(_ value: String) -> (year: Int, month: Int, day: Int)? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        for pattern in datePatterns {
            guard let numbers = captureGroups(of: pattern, in: trimmed)?.compactMap(Int.init),
                  numbers.count == 3 else { continue }
            guard (1...12).contains(numbers[1]), (1...31).contains(numbers[2]) else { return nil }
            return (numbers[0], numbers[1], numbers[2])
        }
        return nil
    }
}
