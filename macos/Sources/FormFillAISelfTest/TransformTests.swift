import Foundation
import FormFillAICore

func runTransformTests(_ t: Harness) {
    t.section("法人格除去（漢字）")
    t.expect(ValueTransformer.removeLegalEntity(from: "株式会社サンプル"), "サンプル", "前方 株式会社")
    t.expect(ValueTransformer.removeLegalEntity(from: "サンプル商事株式会社"), "サンプル商事", "後方 株式会社")
    t.expect(ValueTransformer.removeLegalEntity(from: "合同会社サンプル"), "サンプル", "合同会社")
    t.expect(ValueTransformer.removeLegalEntity(from: "一般社団法人日本◯◯協会"), "日本◯◯協会", "一般社団法人")
    t.expect(ValueTransformer.removeLegalEntity(from: "特定非営利活動法人あいうえお"), "あいうえお", "特定非営利活動法人")
    t.expect(ValueTransformer.removeLegalEntity(from: "NPO法人あいうえお"), "あいうえお", "NPO法人")
    t.expect(ValueTransformer.removeLegalEntity(from: "（株）サンプル"), "サンプル", "（株）")
    t.expect(ValueTransformer.removeLegalEntity(from: "㈱サンプル"), "サンプル", "㈱")
    t.expect(ValueTransformer.removeLegalEntity(from: "サンプル"), "サンプル", "法人格なしはそのまま")
    t.expect(ValueTransformer.removeLegalEntity(from: "株式会社"), "株式会社", "法人格のみなら残す")

    t.section("法人格除去（カナ）")
    t.expect(ValueTransformer.removeLegalEntity(from: "カブシキガイシャサンプル"), "サンプル", "前方カナ")
    t.expect(ValueTransformer.removeLegalEntity(from: "サンプルショウジカブシキガイシャ"), "サンプルショウジ", "後方カナ")
    t.expect(ValueTransformer.removeLegalEntity(from: "カブシキカイシャサンプル"), "サンプル", "カブシキカイシャ")
    t.expect(ValueTransformer.removeLegalEntity(from: "ゴウドウガイシャサンプル"), "サンプル", "ゴウドウガイシャ")
    t.expect(ValueTransformer.removeLegalEntity(from: "かぶしきがいしゃさんぷる"), "さんぷる", "ひらがな")

    t.section("ハイフン・空白除去")
    t.expect(ValueTransformer.removeHyphens(from: "150-0001"), "1500001", "郵便番号")
    t.expect(ValueTransformer.removeHyphens(from: "03-1234-5678"), "0312345678", "電話番号")
    t.expect(ValueTransformer.removeHyphens(from: "０３－１２３４"), "０３１２３４", "全角ハイフン")
    t.expect(ValueTransformer.removeWhitespace(from: "山田 太郎"), "山田太郎", "半角スペース")
    t.expect(ValueTransformer.removeWhitespace(from: "山田　太郎"), "山田太郎", "全角スペース")

    t.section("全角化")
    t.expect(ValueTransformer.toFullWidth(from: "100-0001"), "１００－０００１", "郵便番号")
    t.expect(ValueTransformer.toFullWidth(from: "03-1234-5678"), "０３－１２３４－５６７８", "電話番号")
    t.expect(ValueTransformer.toFullWidth(from: "山田 太郎"), "山田　太郎", "姓名間のスペース")
    t.expect(ValueTransformer.toFullWidth(from: "サンプルビル 3F"), "サンプルビル　３Ｆ", "建物名")
    t.expect(ValueTransformer.toFullWidth(from: "東京都"), "東京都", "漢字はそのまま")

    t.section("分割入力（郵便番号2ボックス / 電話3ボックス / 住所分割）")
    t.expect(ValueTransformer.postalCodePart(from: "100-0001", first: true), "100", "郵便番号 前3桁")
    t.expect(ValueTransformer.postalCodePart(from: "100-0001", first: false), "0001", "郵便番号 後4桁")
    t.expect(ValueTransformer.postalCodePart(from: "1000001", first: true), "100", "ハイフンなしでも切れる")
    t.expect(ValueTransformer.postalCodePart(from: "150-00", first: true), "", "桁数が合わなければ候補にしない")
    t.expect(ValueTransformer.phonePart(from: "03-1234-5678", index: 0), "03", "電話 市外局番")
    t.expect(ValueTransformer.phonePart(from: "03-1234-5678", index: 1), "1234", "電話 市内局番")
    t.expect(ValueTransformer.phonePart(from: "03-1234-5678", index: 2), "5678", "電話 加入者番号")
    t.expect(ValueTransformer.phonePart(from: "0312345678", index: 0), "", "区切りが無ければ候補にしない")

    let addresses = [
        ("東京都千代田区千代田1-1 サンプルビル 3F", "東京都", "千代田区", "千代田1-1 サンプルビル 3F"),
        ("東京都港区芝公園4-2-8 サンプルタワー 6F", "東京都", "港区", "芝公園4-2-8 サンプルタワー 6F"),
        ("神奈川県横浜市西区みなとみらい2-2-1", "神奈川県", "横浜市西区", "みなとみらい2-2-1"),
        ("北海道余市郡余市町黒川町1-1", "北海道", "余市郡余市町", "黒川町1-1"),
    ]
    for (full, prefecture, city, rest) in addresses {
        t.expect(ValueTransformer.addressPart(from: full, part: .prefecture), prefecture, "都道府県")
        t.expect(ValueTransformer.addressPart(from: full, part: .city), city, "市区町村")
        t.expect(ValueTransformer.addressPart(from: full, part: .afterCity), rest, "番地以降")
    }
    t.expect(ValueTransformer.addressPart(from: "サンプルビル 3F", part: .prefecture), "", "住所形式でなければ候補にしない")

    t.section("姓名・メール・URL の分割")
    t.expect(ValueTransformer.namePart(from: "山田 太郎", first: true), "山田", "姓")
    t.expect(ValueTransformer.namePart(from: "山田 太郎", first: false), "太郎", "名")
    t.expect(ValueTransformer.namePart(from: "ヤマダ　タロウ", first: true), "ヤマダ", "セイ（全角スペース区切り）")
    t.expect(ValueTransformer.namePart(from: "TARO YAMADA", first: true), "TARO", "First name")
    t.expect(ValueTransformer.namePart(from: "TARO YAMADA", first: false), "YAMADA", "Last name")
    t.expect(ValueTransformer.namePart(from: "山田太郎", first: true), "", "区切りが無ければ候補にしない")
    t.expect(ValueTransformer.emailPart(from: "taro@example.com", local: true), "taro", "@より前")
    t.expect(ValueTransformer.emailPart(from: "taro@example.com", local: false), "example.com", "@より後")
    t.expect(ValueTransformer.removeScheme(from: "https://example.co.jp/"), "example.co.jp/", "https:// を除く")
    t.expect(ValueTransformer.removeScheme(from: "example.co.jp"), "", "スキームが無ければ候補にしない")

    t.section("クレジットカード")
    t.expect(ValueTransformer.removeWhitespace(from: "1234 5678 9012 3456"), "1234567890123456", "スペースなし")
    t.expect(ValueTransformer.cardPart(from: "1234 5678 9012 3456", index: 0), "1234", "1つ目の4桁")
    t.expect(ValueTransformer.cardPart(from: "1234 5678 9012 3456", index: 3), "3456", "4つ目の4桁")
    t.expect(ValueTransformer.cardPart(from: "3782 822463 10005", index: 0), "", "15桁(Amex)は4分割しない")
    t.expect(ValueTransformer.expiryPart(from: "1/30", variant: .expiryShort), "01/30", "MM/YY")
    t.expect(ValueTransformer.expiryPart(from: "01/30", variant: .expiryLong), "01/2030", "MM/YYYY")
    t.expect(ValueTransformer.expiryPart(from: "01/2030", variant: .expiryYear2), "30", "年2桁")
    t.expect(ValueTransformer.expiryPart(from: "01/30", variant: .expiryYear4), "2030", "年4桁")
    t.expect(ValueTransformer.expiryPart(from: "13/30", variant: .expiryMonth), "", "ありえない月は候補にしない")
    t.expect(ValueTransformer.masked("1234 5678 9012 3456"), "••••••••••••3456", "画面表示は末尾4桁だけ")

    t.section("日付の表記違いと年月日")
    for input in ["1990/1/5", "1990-01-05", "1990年1月5日", "19900105"] {
        t.expect(ValueTransformer.datePart(from: input, variant: .dateSlash), "1990/01/05", "\(input) → スラッシュ")
    }
    t.expect(ValueTransformer.datePart(from: "1990/1/5", variant: .dateKanji), "1990年1月5日", "漢字")
    t.expect(ValueTransformer.datePart(from: "1990/1/5", variant: .dateCompact), "19900105", "8桁")
    t.expect(ValueTransformer.datePart(from: "1990/1/5", variant: .dateYear), "1990", "年")
    t.expect(ValueTransformer.datePart(from: "1990/1/5", variant: .dateMonth), "1", "月")
    t.expect(ValueTransformer.datePart(from: "1990/1/5", variant: .dateMonthPadded), "01", "月（2桁）")
    t.expect(ValueTransformer.datePart(from: "1990/1/5", variant: .dateDayPadded), "05", "日（2桁）")
    t.expect(ValueTransformer.datePart(from: "平成2年1月5日", variant: .dateYear), "", "西暦で読めなければ候補にしない")
    t.expect(ValueTransformer.datePart(from: "1990/13/5", variant: .dateYear), "", "ありえない月は候補にしない")
}
