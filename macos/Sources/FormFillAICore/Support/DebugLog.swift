import Foundation

/// 開発用のローカルログ 1 件。value は決して残さない。
public struct FillLogEntry: Codable, Sendable, Identifiable {
    public var id = UUID()
    public var timestamp = Date()
    public var fieldSignature: String
    public var source: String
    public var selectedCandidateId: String?
    public var selectedProbability: Double?
    public var choiceConfidence: Double?
    public var topAlternatives: [String]
    public var latencyMs: Int
    /// 工程ごとの所要時間（focus / context / classify / paste）。
    public var phases: [String: Int]
    public var corrected: Bool
    public var finalCandidateId: String?
    public var outcome: String

    public init(
        fieldSignature: String, source: String,
        selectedCandidateId: String?, selectedProbability: Double?, choiceConfidence: Double?,
        topAlternatives: [String], latencyMs: Int, phases: [String: Int] = [:],
        corrected: Bool, finalCandidateId: String?, outcome: String
    ) {
        self.fieldSignature = fieldSignature
        self.source = source
        self.selectedCandidateId = selectedCandidateId
        self.selectedProbability = selectedProbability
        self.choiceConfidence = choiceConfidence
        self.topAlternatives = topAlternatives
        self.latencyMs = latencyMs
        self.phases = phases
        self.corrected = corrected
        self.finalCandidateId = finalCandidateId
        self.outcome = outcome
    }
}

/// AX 取得に失敗したときの手がかり。値は含めない。
private struct DiagnosticLine: Codable {
    var timestamp = Date()
    let diagnostic: String
}

@MainActor
public final class DebugLog: ObservableObject {

    @Published public private(set) var entries: [FillLogEntry] = []

    public let logFileURL: URL
    private let maxInMemory = 200

    public init(directory: URL = AppPaths.supportDirectory) {
        logFileURL = directory.appendingPathComponent("fill-log.jsonl")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func append(_ entry: FillLogEntry, enabled: Bool) {
        guard enabled else { return }
        entries.insert(entry, at: 0)
        if entries.count > maxInMemory { entries.removeLast(entries.count - maxInMemory) }
        write(entry)
    }

    public func appendDiagnostic(_ message: String, enabled: Bool) {
        guard enabled else { return }
        write(DiagnosticLine(diagnostic: message))
    }

    /// 同じ入力欄の直近エントリを「修正された」に更新する。
    /// Auto-Paste Precision は「自動入力したのに直された割合」で測るため、
    /// 後から来た修正を元のエントリへ反映する必要がある。
    public func markCorrected(signature: String, finalCandidateId: String) {
        guard let index = entries.firstIndex(where: { $0.fieldSignature == signature && !$0.corrected })
        else { return }
        entries[index].corrected = true
        entries[index].finalCandidateId = finalCandidateId
        write(entries[index])
    }

    /// 直近の実測から Auto-Paste Precision 等を出す。
    public func metricsSummary() -> String {
        guard !entries.isEmpty else { return "ログがありません" }

        let autoPastes = entries.filter { $0.outcome == FillOutcome.autoPaste.rawValue }
        let precision = autoPastes.isEmpty
            ? Double.nan
            : Double(autoPastes.filter { !$0.corrected }.count) / Double(autoPastes.count)
        let total = Double(entries.count)
        let candidateUIRate = Double(entries.filter { $0.outcome == FillOutcome.candidateUI.rawValue }.count) / total
        let correctionRate = Double(entries.filter(\.corrected).count) / total
        let averageLatency = entries.map(\.latencyMs).reduce(0, +) / entries.count

        func percent(_ value: Double) -> String {
            value.isNaN ? "—" : String(format: "%.1f%%", value * 100)
        }

        return """
        件数: \(entries.count)
        自動入力: \(autoPastes.count) 件 / Auto-Paste Precision: \(percent(precision))
        候補UI表示率: \(percent(candidateUIRate))
        修正率: \(percent(correctionRate))
        平均レイテンシ: \(averageLatency) ms
        """
    }

    private func write(_ line: some Encodable) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard var data = try? encoder.encode(line) else { return }
        data.append(0x0A)

        if let handle = try? FileHandle(forWritingTo: logFileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: logFileURL, options: [.atomic])
        }
    }
}
