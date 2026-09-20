import Foundation

/// ユーザーが登録した原本データ。
/// value は Keychain 側に保持されるため、永続化時はメタデータと分離する。
public struct ProfileItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var label: String
    public var value: String
    public var semanticType: SemanticType
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        label: String,
        value: String,
        semanticType: SemanticType = .custom,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.semanticType = semanticType
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Profile Item の登録上限。仕様は 50 だが、2 つ目以降のセットを持てるよう広げている。
    /// 実際の制約は Jev の選択肢数（255）で、VirtualCandidateBuilder.maxCandidates が守る。
    public static let maxCount = 90

    /// UUID から導出する安定した短い ID 断片。候補 ID に使う。
    public var shortKey: String {
        String(id.uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).lowercased()
    }
}

/// 永続化するのはメタデータのみ。value はここに含めない。
public struct ProfileItemMetadata: Codable, Sendable {
    public var id: UUID
    public var label: String
    public var semanticType: SemanticType
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(_ item: ProfileItem) {
        self.id = item.id
        self.label = item.label
        self.semanticType = item.semanticType
        self.sortOrder = item.sortOrder
        self.createdAt = item.createdAt
        self.updatedAt = item.updatedAt
    }

    public func item(value: String) -> ProfileItem {
        ProfileItem(
            id: id, label: label, value: value, semanticType: semanticType,
            sortOrder: sortOrder, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}
