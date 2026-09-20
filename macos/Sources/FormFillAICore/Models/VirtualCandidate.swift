import Foundation

/// 実際に入力可能な最終候補。
/// value は保持しない。必要になった時点で ProfileItem.value + variant から生成する。
public struct VirtualCandidate: Identifiable, Hashable, Sendable {
    public let id: String
    public let sourceProfileItemId: UUID
    public let label: String
    public let variant: ValueVariant

    /// 元になった Profile Item の項目名（変換の注記を含まない）。別セットの同じ項目を探すのに使う。
    public let itemLabel: String

    /// Jev へ送る候補説明。項目名と表記形式のみで、value は含めない。
    public let criteria: String

    public init(id: String, sourceProfileItemId: UUID, itemLabel: String, label: String, variant: ValueVariant, criteria: String) {
        self.id = id
        self.sourceProfileItemId = sourceProfileItemId
        self.itemLabel = itemLabel
        self.label = label
        self.variant = variant
        self.criteria = criteria
    }

    /// 「該当なし」を表す予約 ID。
    public static let noneId = "__none__"
}
