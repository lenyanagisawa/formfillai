import Foundation
import Security

/// Profile Item の value を Keychain に保存する。
///
/// 項目ごとに Keychain アイテムを作ると再署名のたびにアクセス確認が項目数だけ出るため、
/// 全 value をまとめた 1 件の generic password として保持する。
public final class KeychainStore: @unchecked Sendable {

    public enum KeychainError: LocalizedError {
        case unexpectedStatus(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
                return "Keychain エラー (\(status)): \(message)"
            }
        }
    }

    private let service: String
    private let account: String
    private let lock = NSLock()

    public init(service: String = "io.github.lenyanagisawa.FormFillAI", account: String = "profile-values") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    /// itemID(UUID 文字列) -> value
    public func loadAll() throws -> [String: String] {
        lock.lock(); defer { lock.unlock() }

        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        case errSecItemNotFound:
            return [:]
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func saveAll(_ values: [String: String]) throws {
        lock.lock(); defer { lock.unlock() }

        let data = try JSONEncoder().encode(values)

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(updateStatus)
        }

        var addQuery = baseQuery
        addQuery.merge(attributes) { _, new in new }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    public func deleteAll() throws {
        lock.lock(); defer { lock.unlock() }
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
