import Foundation

/// Profile Item から Virtual Candidate を生成する。
/// semanticType ごとに自然な Variant のみを作り、選択肢を無駄に増やさない。
public enum VirtualCandidateBuilder {

    /// Jev の Choice は 255 択まで。NONE の 1 枠を除いた数に収める。
    public static let maxCandidates = 254

    /// 並び順（よく使うセットが前）を保ったまま、上限を超えた分は後ろから捨てる。
    public static func build(from items: [ProfileItem]) -> [VirtualCandidate] {
        Array(items
            .sorted { $0.sortOrder < $1.sortOrder }
            .flatMap { build(from: $0) }
            .prefix(maxCandidates))
    }

    public static func build(from item: ProfileItem) -> [VirtualCandidate] {
        let trimmedValue = item.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return [] }

        var result: [VirtualCandidate] = []
        var seenValues = Set<String>()

        for variant in item.semanticType.allowedVariants {
            let produced = ValueTransformer.apply(variant, to: item.value)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // 変換しても値が変わらない Variant は候補にしない。
            // 例: 「サンプル」（法人格なし）や「ヤマダタロウ」（スペースなし）。
            guard !produced.isEmpty, seenValues.insert(produced).inserted else { continue }

            result.append(
                VirtualCandidate(
                    id: candidateId(item: item, variant: variant),
                    sourceProfileItemId: item.id,
                    itemLabel: item.label,
                    label: label(item: item, variant: variant),
                    variant: variant,
                    criteria: criteria(item: item, variant: variant)
                )
            )
        }
        return result
    }

    /// Jev へ渡せる ASCII の安定 ID。ラベルが日本語でも破綻しない。
    static func candidateId(item: ProfileItem, variant: ValueVariant) -> String {
        "\(item.semanticType.slug)_\(item.shortKey)__\(variant.slug)"
    }

    /// UI 表示用のラベル。例:「会社名フリガナ（法人格なし）」
    static func label(item: ProfileItem, variant: ValueVariant) -> String {
        guard let suffix = variant.labelSuffix else { return item.label }
        return "\(item.label)（\(suffix)）"
    }

    /// Jev へ渡す候補の説明。項目名と表記形式のみ。value は含めない。
    static func criteria(item: ProfileItem, variant: ValueVariant) -> String {
        guard let suffix = variant.criteriaSuffix else { return item.label }
        return "\(item.label)（\(suffix)）"
    }
}
