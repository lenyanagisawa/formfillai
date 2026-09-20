import Foundation
import FormFillAICore

func runCandidateTests(_ t: Harness) {
    let candidates = Fixtures.candidates
    func has(_ label: String) -> Bool { candidates.contains { $0.label == label } }
    func hasVariant(of prefix: String) -> Bool { candidates.contains { $0.label.hasPrefix("\(prefix)（") } }

    t.section("Virtual Candidate 生成")
    t.expect(candidates.count, 30, "候補総数")
    t.expectTrue(has("会社名（法人格なし）"), "会社名（法人格なし）がある")
    t.expectTrue(has("会社名フリガナ（法人格なし）"), "会社名フリガナ（法人格なし）がある")
    t.expectTrue(has("氏名（全角）"), "氏名に全角候補がある（姓名間の全角スペース）")
    t.expectTrue(has("郵便番号（全角）"), "郵便番号に全角候補がある")
    t.expectTrue(has("郵便番号（前3桁）"), "郵便番号2ボックス用の候補がある")
    t.expectTrue(has("電話番号（市外局番）"), "電話3ボックス用の候補がある")
    t.expectTrue(has("氏名（姓）") && has("氏名（名）"), "姓・名の分割候補がある")
    t.expectTrue(has("氏名カナ（姓）") && has("氏名カナ（名）"), "セイ・メイの分割候補がある")
    t.expectTrue(has("メールアドレス（@より前）"), "メール2ボックス用の候補がある")
    t.expectTrue(!has("メールアドレス（全角）"), "メールに全角候補を作らない")
    t.expectTrue(!hasVariant(of: "役職"), "役職に無意味なVariantが無い")
    t.expectTrue(!hasVariant(of: "サービス名"), "customはrawのみ")

    t.section("登録フォームのテンプレート")
    let labels = ProfileTemplate.allFields.map(\.label)
    t.expectTrue(Set(labels).count == labels.count, "項目名が重複していない（重複すると Jev が区別できない）")
    t.expectTrue(labels.count <= ProfileItem.maxCount, "全部埋めても登録上限に収まる（\(labels.count) 欄）")
    // プレースホルダは記入例。その通りに入れたとき、切り出しに失敗する変換があってはいけない
    // （例: 氏名の記入例にスペースが無いと、姓・名の候補が作られない）。
    // 「町名・番地のみ」のような部分欄は、もともと住所全体ではないので対象外。
    for field in ProfileTemplate.allFields where !field.title.hasSuffix("のみ") && field.semanticType != .custom {
        let failed = field.semanticType.allowedVariants.filter {
            ValueTransformer.apply($0, to: field.placeholder).isEmpty
        }
        t.expectTrue(failed.isEmpty, "「\(field.label)」の記入例で全変換が成立する\(failed.isEmpty ? "" : " 失敗: \(failed)")")
    }

    t.section("2 つ目以降のセット")
    let cardField = ProfileTemplate.allFields.first { $0.label == "クレジットカード番号" }!
    let scoped = cardField.scoped(to: "法人カード")
    t.expect(scoped.label, "法人カード：クレジットカード番号", "項目名にセット名が付く")
    t.expectTrue(scoped.isSensitive, "別セットでも機密扱いが引き継がれる")
    let parsed = ProfileTemplate.parseScoped(scoped.label)
    t.expectTrue(parsed?.setName == "法人カード" && parsed?.field.label == "クレジットカード番号", "項目名からセットと欄を復元できる")
    t.expectTrue(ProfileTemplate.parseScoped("メモ：自由入力") == nil, "フォームに無い項目はセット扱いしない")

    let cards = [
        ProfileItem(label: cardField.label, value: "1111 2222 3333 4444", semanticType: .creditCardNumber, sortOrder: 0),
        ProfileItem(label: scoped.label, value: "5555 6666 7777 8888", semanticType: .creditCardNumber, sortOrder: 1),
        ProfileItem(label: "カード名義", value: "TARO YAMADA", semanticType: .custom, sortOrder: 2),
    ]
    t.expectTrue(!ProfileTemplate.isCustom(cards[1]), "別セットの項目は「その他の項目」に落ちない")
    t.expectTrue(ProfileTemplate.extraSetNames(in: cards)["支払い（クレジットカード）"] == ["法人カード"], "登録済みの項目名からセット一覧を復元できる")

    let cardCandidates = VirtualCandidateBuilder.build(from: cards)
    let primary = cardCandidates.first { $0.itemLabel == cardField.label && $0.variant == .removeWhitespace }!
    let alternatives = CandidateRanker.rank(cardCandidates, by: nil, excluding: primary)
    t.expectTrue(alternatives.first?.candidate.itemLabel == scoped.label && alternatives.first?.candidate.variant == .removeWhitespace,
                 "「違う」の先頭に、別セットの同じ項目・同じ表記が来る")

    t.section("候補 ID")
    t.expectTrue(candidates.allSatisfy { $0.id.allSatisfy(\.isASCII) }, "全候補 ID が ASCII")
    t.expectTrue(Set(candidates.map(\.id)).count == candidates.count, "候補 ID が一意")

    t.section("候補から値を生成")
    for candidate in candidates where candidate.variant != .raw {
        t.say("  \(candidate.label) -> \(Fixtures.value(of: candidate))")
    }
    if let kana = candidates.first(where: { $0.label == "会社名フリガナ（法人格なし）" }) {
        t.expect(Fixtures.value(of: kana), "サンプル", " の代表ケース")
    }

    t.section("候補の並べ替え（CandidateRanker）")
    let raw = candidates.first { $0.label == "会社名" }!
    let bare = candidates.first { $0.label == "会社名（法人格なし）" }!
    let result = ClassificationResult(
        selectedCandidateId: VirtualCandidate.noneId, selectedProbability: 0.5, choiceConfidence: nil,
        alternatives: [
            .init(candidateId: VirtualCandidate.noneId, probability: 0.5),
            .init(candidateId: bare.id, probability: 0.3),
            .init(candidateId: raw.id, probability: 0.2),
        ]
    )
    let ranked = CandidateRanker.rank(candidates, by: result)
    t.expectTrue(ranked.first?.candidate.id == bare.id, "確率の高い実候補が先頭に来る")
    t.expectTrue(ranked.count == candidates.count, "分布に無い候補も後ろに残る")
    t.expectTrue(CandidateRanker.rank(candidates, by: result, excluding: bare).allSatisfy { $0.candidate.id != bare.id },
                 "除外した候補は出てこない")
    t.expectTrue(CandidateRanker.bestConcrete(in: result, from: candidates)?.id == bare.id,
                 "NONE が1位でも最も確率の高い実候補を返す（常に自動入力）")
}
