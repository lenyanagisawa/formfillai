import Foundation

/// Jev の確率分布を、UI と入力判断で使える形に並べ替える。副作用なし。
public enum CandidateRanker {

    /// Jev の分布順に並べ、分布に無い候補は後ろへ回す。
    public static func rank(
        _ candidates: [VirtualCandidate],
        by result: ClassificationResult?,
        excluding excluded: VirtualCandidate? = nil
    ) -> [RankedCandidate] {
        let byId = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        var used = Set<String>()
        if let excluded { used.insert(excluded.id) }

        var ranked: [RankedCandidate] = []

        // 「違う」で選び直すときは、別セットの同じ項目（カード 1 → カード 2 など）が最有力。
        // Jev の確率に関わらず先頭へ出して、1 クリックで切り替えられるようにする。
        if let excluded {
            for sibling in candidates where isCounterpart(sibling, of: excluded) && used.insert(sibling.id).inserted {
                ranked.append(RankedCandidate(candidate: sibling, probability: result?.probability(of: sibling.id)))
            }
        }

        for alternative in result?.sortedAlternatives ?? [] {
            guard let candidate = byId[alternative.candidateId],
                  used.insert(candidate.id).inserted else { continue }
            ranked.append(RankedCandidate(candidate: candidate, probability: alternative.probability))
        }
        for candidate in candidates where !used.contains(candidate.id) {
            ranked.append(RankedCandidate(candidate: candidate, probability: nil))
        }
        return ranked
    }

    /// セット違いの同じ項目・同じ変換かどうか。
    static func isCounterpart(_ candidate: VirtualCandidate, of other: VirtualCandidate) -> Bool {
        candidate.id != other.id
            && candidate.variant == other.variant
            && baseLabel(candidate.itemLabel) == baseLabel(other.itemLabel)
            && candidate.itemLabel != other.itemLabel
    }

    private static func baseLabel(_ itemLabel: String) -> String {
        ProfileTemplate.parseScoped(itemLabel)?.field.label ?? itemLabel
    }

    /// 分布の中で最も確率の高い「実際に入力できる候補」。NONE は飛ばす。
    public static func bestConcrete(
        in result: ClassificationResult,
        from candidates: [VirtualCandidate]
    ) -> VirtualCandidate? {
        let byId = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        if !result.selectedIsNone, let selected = byId[result.selectedCandidateId] {
            return selected
        }
        return result.sortedAlternatives.lazy.compactMap { byId[$0.candidateId] }.first
    }
}
