import Foundation

/// 分割入力: 1 つの情報が複数の入力欄に分かれているフォーム向けの切り出し。
extension ValueTransformer {

    /// 郵便番号 2 ボックス。「150」「0002」
    public static func postalCodePart(from value: String, first: Bool) -> String {
        let digits = value.filter(\.isNumber)
        guard digits.count == 7 else { return "" }
        return first ? String(digits.prefix(3)) : String(digits.suffix(4))
    }

    /// 電話番号 3 ボックス。「03」「1234」「5678」。区切りが無いと切る位置を決められない。
    public static func phonePart(from value: String, index: Int) -> String {
        let parts = value.split(whereSeparator: { hyphens.contains($0) }).map(String.init)
        guard parts.count == 3, parts.indices.contains(index) else { return "" }
        return parts[index]
    }

    /// 「山田 太郎」→ 山田 / 太郎。ローマ字は「First Last」の順で登録されている前提で前後を返す。
    /// ちょうど 2 語に分かれないときは、どこで切るか決められないので候補にしない。
    public static func namePart(from value: String, first: Bool) -> String {
        let parts = value.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count == 2 else { return "" }
        return first ? parts[0] : parts[1]
    }

    /// 「xxx @ yyy」の 2 ボックス。
    public static func emailPart(from value: String, local: Bool) -> String {
        let parts = value.split(separator: "@", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return "" }
        return local ? parts[0] : parts[1]
    }

    public enum AddressPart { case prefecture, city, afterCity }

    /// 都道府県 →（郡+町村 | 市+区 | 市区町村のいずれか）→ 残り。
    /// 政令市の行政区（横浜市西区）と郡部（〇〇郡〇〇町）も 1 つの市区町村として扱う。
    private static let addressPattern = try! NSRegularExpression(
        pattern: "^(北海道|東京都|京都府|大阪府|.{2,3}県)(.+?郡.+?[町村]|.+?市.+?区|.+?[市区町村])(.*)$"
    )

    /// 「東京都千代田区千代田1-1 サンプルビル 3F」→ 東京都 / 渋谷区 / 千代田1-1 サンプルビル 3F
    public static func addressPart(from value: String, part: AddressPart) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let groups = captureGroups(of: addressPattern, in: trimmed), groups.count == 3 else { return "" }
        switch part {
        case .prefecture: return groups[0]
        case .city: return groups[1]
        case .afterCity: return groups[2]
        }
    }

    /// 全キャプチャグループを前後の空白を落として返す。マッチしなければ nil。
    static func captureGroups(of regex: NSRegularExpression, in text: String) -> [String]? {
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text)
                .map { String(text[$0]).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        }
    }
}
