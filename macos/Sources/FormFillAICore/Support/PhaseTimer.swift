import Foundation

/// 工程ごとの所要時間を測る。どこが遅いかをログから追えるようにする。
public struct PhaseTimer {
    public let startedAt = Date()
    private var lastMark = Date()
    public private(set) var phases: [String: Int] = [:]

    public init() {}

    /// 直前の mark からここまでを `name` の所要時間として記録する。
    public mutating func mark(_ name: String) {
        let now = Date()
        phases[name, default: 0] += Int(now.timeIntervalSince(lastMark) * 1000)
        lastMark = now
    }

    public var totalMs: Int { Int(Date().timeIntervalSince(startedAt) * 1000) }
}
