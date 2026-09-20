import Foundation

/// 表記違い: 法人格・ハイフン・空白の除去、全角化、URL のスキーム除去。
extension ValueTransformer {

    // MARK: - 法人格除去

    /// 前方・後方どちらに付いた法人格も 1 つだけ除去する。
    public static func removeLegalEntity(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        for token in LegalEntityTables.allTokens where trimmed.count > token.count {
            if trimmed.hasPrefix(token) { return trimSeparators(String(trimmed.dropFirst(token.count))) }
            if trimmed.hasSuffix(token) { return trimSeparators(String(trimmed.dropLast(token.count))) }
        }
        return trimmed
    }

    /// 法人格を落とした跡に残る区切り文字と空白を除去する。
    private static func trimSeparators(_ value: String) -> String {
        let separators = CharacterSet(charactersIn: "・･、,， \u{3000}\u{00A0}-‐－ー").union(.whitespacesAndNewlines)
        return value.trimmingCharacters(in: separators)
    }

    // MARK: - ハイフン・空白

    static let hyphens: Set<Character> = [
        "-", "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2014}", "\u{2015}",
        "\u{2212}",  // MINUS SIGN
        "\u{FF0D}",  // 全角ハイフンマイナス
        "\u{30FC}",  // 長音記号（電話番号の区切りに使われることがある）
        "\u{FF70}",  // 半角長音記号
    ]

    /// 郵便番号・電話番号向け。カナ項目には適用されない。
    public static func removeHyphens(from value: String) -> String {
        String(value.filter { !hyphens.contains($0) })
    }

    public static func removeWhitespace(from value: String) -> String {
        String(value.filter { !$0.isWhitespace })
    }

    // MARK: - 全角化

    /// ASCII の英数字・記号・空白を全角へ置き換える。
    /// 「全角で入力してください」と指定するフォーム向け。漢字・かなはそのまま残る。
    public static func toFullWidth(from value: String) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.map { scalar in
            if scalar.value == 0x20 { return Unicode.Scalar(0x3000)! }
            if (0x21...0x7E).contains(scalar.value), let wide = Unicode.Scalar(scalar.value + 0xFEE0) {
                return wide
            }
            return scalar
        }))
    }

    // MARK: - URL

    /// 入力欄の前に「https://」が固定表示されているフォーム向け。
    public static func removeScheme(from value: String) -> String {
        for scheme in ["https://", "http://"] where value.lowercased().hasPrefix(scheme) {
            return String(value.dropFirst(scheme.count))
        }
        return ""
    }
}
