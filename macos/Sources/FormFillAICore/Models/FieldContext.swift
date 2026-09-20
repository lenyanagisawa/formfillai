import Foundation

/// フォーカス中の入力欄から取得したコンテキスト。
/// 現在入力されている value は含めない。
public struct FieldContext: Codable, Sendable, Equatable {
    public struct Application: Codable, Sendable, Equatable {
        public var name: String?
        public var bundleId: String?
        public init(name: String?, bundleId: String?) {
            self.name = name
            self.bundleId = bundleId
        }
    }

    public struct Window: Codable, Sendable, Equatable {
        public var title: String?
        public init(title: String?) { self.title = title }
    }

    public struct Page: Codable, Sendable, Equatable {
        public var domain: String?
        public var title: String?
        public init(domain: String?, title: String?) {
            self.domain = domain
            self.title = title
        }
    }

    public struct Field: Codable, Sendable, Equatable {
        public var role: String?
        public var subrole: String?
        public var title: String?
        public var placeholder: String?
        public var description: String?
        public var help: String?
        public var nearbyTexts: [String]

        /// 同じ種類の入力欄が並んでいるときの位置（1 始まり）。
        /// 郵便番号 2 ボックスや電話 3 ボックスのどれなのかを判断する手がかりになる。
        public var siblingIndex: Int?
        public var siblingCount: Int?

        public init(
            role: String?, subrole: String? = nil, title: String?, placeholder: String?,
            description: String?, help: String?, nearbyTexts: [String],
            siblingIndex: Int? = nil, siblingCount: Int? = nil
        ) {
            self.role = role
            self.subrole = subrole
            self.title = title
            self.placeholder = placeholder
            self.description = description
            self.help = help
            self.nearbyTexts = nearbyTexts
            self.siblingIndex = siblingIndex
            self.siblingCount = siblingCount
        }
    }

    public var application: Application
    public var window: Window
    public var page: Page?
    public var field: Field

    public init(application: Application, window: Window, page: Page?, field: Field) {
        self.application = application
        self.window = window
        self.page = page
        self.field = field
    }

    /// 入力欄について何らかの手がかりがあるか。全く無い場合は Jev を呼んでも意味がない。
    public var hasAnyFieldHint: Bool {
        let hints = [field.title, field.placeholder, field.description, field.help]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return !hints.isEmpty || !field.nearbyTexts.isEmpty
    }
}
