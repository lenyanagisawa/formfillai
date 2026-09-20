import Foundation

/// 法人格の表記テーブル。
/// 除去は Swift 側で決定論的に行う。Jev には一切変換させない。
public enum LegalEntityTables {

    /// 漢字表記の法人格。前方・後方のどちらに付いていても除去する。
    public static let kanji: [String] = [
        "特定非営利活動法人",
        "一般社団法人",
        "一般財団法人",
        "公益社団法人",
        "公益財団法人",
        "社会福祉法人",
        "国立大学法人",
        "独立行政法人",
        "NPO法人",
        "ＮＰＯ法人",
        "医療法人",
        "学校法人",
        "宗教法人",
        "株式会社",
        "有限会社",
        "合同会社",
        "合資会社",
        "合名会社",
    ]

    /// 括弧・記号による略称表記。
    public static let abbreviations: [String] = [
        "（株）", "(株)", "㈱",
        "（有）", "(有)", "㈲",
        "（合）", "(合)",
        "（同）", "(同)",
        "（財）", "(財)", "㈶",
        "（社）", "(社)", "㈳",
    ]

    /// カナ表記の法人格。フリガナ項目で使う。
    public static let kana: [String] = [
        "トクテイヒエイリカツドウホウジン",
        "イッパンシャダンホウジン",
        "イッパンザイダンホウジン",
        "コウエキシャダンホウジン",
        "コウエキザイダンホウジン",
        "シャカイフクシホウジン",
        "コクリツダイガクホウジン",
        "ドクリツギョウセイホウジン",
        "エヌピーオーホウジン",
        "イリョウホウジン",
        "ガッコウホウジン",
        "シュウキョウホウジン",
        "カブシキガイシャ",
        "カブシキカイシャ",
        "ユウゲンガイシャ",
        "ユウゲンカイシャ",
        "ゴウドウガイシャ",
        "ゴウドウカイシャ",
        "ゴウシガイシャ",
        "ゴウシカイシャ",
        "ゴウメイガイシャ",
        "ゴウメイカイシャ",
    ]

    /// ひらがな表記（フリガナ欄にひらがなで登録した場合に対応）。
    public static let hiragana: [String] = kana.map { hiraganaize($0) }

    /// 長い順に並べた全トークン。先に長いものから照合する。
    public static let allTokens: [String] = {
        let tokens = kanji + abbreviations + kana + hiragana
        // 重複除去しつつ長い順に安定ソート
        var seen = Set<String>()
        let unique = tokens.filter { seen.insert($0).inserted }
        return unique.sorted { $0.count > $1.count }
    }()

    /// カタカナをひらがなへ変換する（テーブル生成用）。
    static func hiraganaize(_ s: String) -> String {
        String(String.UnicodeScalarView(s.unicodeScalars.map { scalar in
            if scalar.value >= 0x30A1 && scalar.value <= 0x30F6,
               let converted = Unicode.Scalar(scalar.value - 0x60) {
                return converted
            }
            return scalar
        }))
    }
}
