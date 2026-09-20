import Foundation
import FormFillAICore

func runProtocolTests(_ t: Harness) {
    t.section("Jev へ送る内容に登録値が混ざらないこと")
    let encoded = Fixtures.requestJSON
    for item in Fixtures.items {
        t.expectTrue(!encoded.contains(item.value), "\(item.label) の値が送信ペイロードに含まれない")
    }

    t.section("Field Signature")
    let base = FieldSignature.make(from: Fixtures.context)
    t.expectTrue(base == FieldSignature.make(from: Fixtures.context), "同一の欄で署名が一致")

    var otherField = Fixtures.context
    otherField.field.title = "会社名"
    t.expectTrue(base != FieldSignature.make(from: otherField), "違う欄で署名が変わる")

    var firstBox = Fixtures.context, secondBox = Fixtures.context
    firstBox.field.siblingIndex = 1
    secondBox.field.siblingIndex = 2
    t.expectTrue(FieldSignature.make(from: firstBox) != FieldSignature.make(from: secondBox),
                 "属性が同じでも、並び順が違えば別の欄として扱う（郵便番号2ボックス）")

    t.section("Jev への問い合わせ")
    let parsedRequest = try! JSONSerialization.jsonObject(with: Data(encoded.utf8)) as! [String: Any]
    let question = (parsedRequest["questions"] as! [String: Any])[JevPrompt.questionKey] as! [String: Any]
    let criteria = question["criteria"] as! [String: Any]
    t.expectTrue(question["type"] as? String == "choice", "質問は choice 1 つだけ")
    t.expectTrue(criteria.count == Fixtures.candidates.count + 1, "全候補 + 該当なし が選択肢になる")
    t.expectTrue(criteria[JevPrompt.noneOptionKey] != nil, "該当なしの選択肢を必ず含む")
    // 選択肢の並び（よく使うものが前）は意味を持つので、直列化で崩れてはいけない。
    let firstTwo = Fixtures.candidates.prefix(2).map(\.id)
    t.expectTrue(encoded.range(of: firstTwo[0])!.lowerBound < encoded.range(of: firstTwo[1])!.lowerBound, "選択肢の順序が保たれる")
    t.expect(JevPrompt.positionHint(index: 2, count: 3) ?? "", "同じ種類の入力欄が3つ並んでいるうちの2番目（中央）", "並び順は言葉で渡す")
    t.expectTrue(JevPrompt.positionHint(index: nil, count: nil) == nil, "並んでいなければヒントを付けない")

    t.section("経路ごとのリクエスト")
    var credentials = JevConnection.Credentials()
    t.expectTrue(JevConnection.allCases.allSatisfy { !$0.isConfiguredForTest(credentials) }, "未設定の経路は使えない")
    credentials.gatewayKey = "gw-key"; credentials.typesafeKey = "ts-key"
    credentials.relayURL = "https://relay.example.com/api/evaluate"; credentials.relayToken = "relay-token"
    for connection in JevConnection.allCases {
        let request = connection.requestForTest(credentials: credentials)
        let body = String(decoding: request?.httpBody ?? Data(), as: UTF8.self)
        t.expectTrue(request?.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true, "\(connection.rawValue): 認証ヘッダが付く")
        t.expectTrue(body.contains("\"criteria\"") && body.contains(JevPrompt.noneOptionKey), "\(connection.rawValue): 同じ問い合わせ内容が送られる")
    }

    t.section("Jev の回答の読み取り")
    let responses: [(String, String)] = [
        ("AI Gateway", #"{"answers":{"field":{"type":"choice","choice":"a__raw","probabilities":{"a__raw":0.97,"none_of_the_above":0.03}}},"providerMetadata":{"typesafe":{"confidence":{"field":0.94}}}}"#),
        ("確率分布なし", #"{"answers":{"field":{"type":"choice","choice":"a__raw"}}}"#),
        ("該当なし", #"{"answers":{"field":{"type":"choice","choice":"none_of_the_above","probabilities":{"none_of_the_above":0.71}}}}"#),
    ]
    let parsed = responses.map { try? JevPrompt.parse(Data($0.1.utf8)) }
    t.expectTrue(parsed.allSatisfy { $0 != nil }, "どの形の回答も読める")
    t.expectTrue(parsed[0]?.selectedProbability == 0.97 && parsed[0]?.choiceConfidence == 0.94, "確率と確信度を取り出せる")
    t.expectTrue(parsed[1]?.selectedProbability == 0, "分布が無ければ確率 0（しきい値方式では自動入力しない）")
    t.expectTrue(parsed[2]?.selectedIsNone == true, "該当なしを NONE として扱う")
}
