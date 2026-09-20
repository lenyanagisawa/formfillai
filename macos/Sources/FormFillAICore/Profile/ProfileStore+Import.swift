import Foundation

extension ProfileStore {

    // MARK: - 一括登録

    /// JSON からまとめて登録する。1 件ずつ手入力するのが現実的でない件数のため。
    public struct ImportEntry: Decodable {
        public let label: String
        public let value: String
        public let semanticType: String?
    }

    public struct ImportSummary {
        public var added = 0
        public var updated = 0
        public var skipped = 0
    }

    public enum ImportError: LocalizedError {
        case unreadable(String)

        public var errorDescription: String? {
            switch self {
            case .unreadable(let detail): return "読み込めませんでした: \(detail)"
            }
        }
    }

    /// 同じ項目名があれば上書きする。何度読み込んでも重複しない。
    ///
    /// - Parameter replaceAll: true なら既存の登録をすべて消してから入れ直す。
    ///   項目を減らしたいときは追加・更新だけでは消せないため。
    @discardableResult
    public func importItems(from url: URL, replaceAll: Bool = false) throws -> ImportSummary {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.unreadable(error.localizedDescription)
        }

        let entries: [ImportEntry]
        do {
            entries = try JSONDecoder().decode([ImportEntry].self, from: data)
        } catch {
            throw ImportError.unreadable(error.localizedDescription)
        }

        var summary = ImportSummary()
        if replaceAll { items.removeAll() }
        for entry in entries {
            let label = entry.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty, !value.isEmpty else {
                summary.skipped += 1
                continue
            }
            let type = Self.semanticType(from: entry.semanticType)

            if let index = items.firstIndex(where: { $0.label == label }) {
                items[index].value = value
                items[index].semanticType = type
                items[index].updatedAt = Date()
                summary.updated += 1
            } else if canAddMore {
                items.append(ProfileItem(
                    label: label, value: value, semanticType: type,
                    sortOrder: (items.map(\.sortOrder).max() ?? -1) + 1
                ))
                summary.added += 1
            } else {
                summary.skipped += 1
            }
        }
        persist()
        return summary
    }

    /// `"companyName"` でも `"会社名"` でも受け付ける。判別できなければ custom。
    static func semanticType(from raw: String?) -> SemanticType {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return .custom
        }
        if let matched = SemanticType(rawValue: raw) { return matched }
        if let matched = SemanticType.allCases.first(where: { $0.defaultLabel == raw }) { return matched }
        return .custom
    }
}
