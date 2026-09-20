import Foundation

/// Jev の回答を、アプリ内で扱いやすい形にしたもの。
public struct ClassificationResult: Codable, Sendable {
    public struct Alternative: Codable, Sendable {
        public let candidateId: String
        public let probability: Double
        public init(candidateId: String, probability: Double) {
            self.candidateId = candidateId
            self.probability = probability
        }
    }

    public let selectedCandidateId: String
    public let selectedProbability: Double
    public let choiceConfidence: Double?
    public let alternatives: [Alternative]

    public init(
        selectedCandidateId: String,
        selectedProbability: Double,
        choiceConfidence: Double?,
        alternatives: [Alternative]
    ) {
        self.selectedCandidateId = selectedCandidateId
        self.selectedProbability = selectedProbability
        self.choiceConfidence = choiceConfidence
        self.alternatives = alternatives
    }

    public var selectedIsNone: Bool { selectedCandidateId == VirtualCandidate.noneId }

    /// 確率の高い順。
    public var sortedAlternatives: [Alternative] {
        alternatives.sorted { $0.probability > $1.probability }
    }

    public func probability(of candidateId: String) -> Double? {
        alternatives.first { $0.candidateId == candidateId }?.probability
    }
}
