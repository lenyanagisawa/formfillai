import Foundation

/// Profile Item の CRUD。
///
/// メタデータは Application Support の JSON、value は Keychain に分けて保存する。
/// （仕様では SwiftData を推奨しているが、@Model マクロは Xcode 同梱のプラグインが必要で
///   Command Line Tools だけの環境ではビルドできないため、同じ責務を JSON で実装している。）
@MainActor
public final class ProfileStore: ObservableObject {

    @Published public internal(set) var items: [ProfileItem] = []
    @Published public private(set) var lastError: String?

    func reportError(_ message: String) { lastError = message }

    private let metadataURL: URL
    private let keychain: KeychainStore

    public init(
        directory: URL = AppPaths.supportDirectory,
        keychain: KeychainStore = KeychainStore()
    ) {
        self.metadataURL = directory.appendingPathComponent("profile-items.json")
        self.keychain = keychain
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
    }

    public var canAddMore: Bool { items.count < ProfileItem.maxCount }

    // MARK: - CRUD

    @discardableResult
    public func add(label: String, value: String, semanticType: SemanticType) -> ProfileItem? {
        guard canAddMore else {
            lastError = "登録できるのは \(ProfileItem.maxCount) 件までです"
            return nil
        }
        let item = ProfileItem(
            label: label,
            value: value,
            semanticType: semanticType,
            sortOrder: (items.map(\.sortOrder).max() ?? -1) + 1
        )
        items.append(item)
        persist()
        return item
    }

    public func update(_ item: ProfileItem, label: String, value: String, semanticType: SemanticType) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].label = label
        items[index].value = value
        items[index].semanticType = semanticType
        items[index].updatedAt = Date()
        persist()
    }

    public func delete(_ item: ProfileItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    /// 並べ替え。SwiftUI へ依存しないよう自前で実装している。
    public func move(fromOffsets: IndexSet, toOffset: Int) {
        let moving = fromOffsets.sorted().map { items[$0] }
        let insertionIndex = toOffset - fromOffsets.filter { $0 < toOffset }.count
        for index in fromOffsets.sorted(by: >) { items.remove(at: index) }
        items.insert(contentsOf: moving, at: min(max(insertionIndex, 0), items.count))
        for (index, _) in items.enumerated() { items[index].sortOrder = index }
        persist()
    }

    public func item(id: UUID) -> ProfileItem? { items.first { $0.id == id } }

    // MARK: - Virtual Candidate

    /// 現在の登録内容から Virtual Candidate 一式を作る。
    public func virtualCandidates() -> [VirtualCandidate] {
        VirtualCandidateBuilder.build(from: items)
    }

    /// 候補 ID から最終入力値を生成する。100% ローカル処理。
    public func resolveValue(for candidate: VirtualCandidate) -> String? {
        guard let source = item(id: candidate.sourceProfileItemId) else { return nil }
        return ValueTransformer.apply(candidate.variant, to: source.value)
    }

    /// 画面に出すための値。カード番号などは末尾だけ残して伏せる。
    public func displayValue(for candidate: VirtualCandidate) -> String? {
        guard let source = item(id: candidate.sourceProfileItemId),
              let value = resolveValue(for: candidate) else { return nil }
        let sensitive = source.semanticType.isSensitive || ProfileTemplate.isSensitive(label: source.label)
        return sensitive ? ValueTransformer.masked(value) : value
    }

    // MARK: - 永続化

    private func load() {
        do {
            let values = try keychain.loadAll()
            guard let data = try? Data(contentsOf: metadataURL) else { return }
            let metadata = try JSONDecoder.appDefault.decode([ProfileItemMetadata].self, from: data)
            items = metadata
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { $0.item(value: values[$0.id.uuidString] ?? "") }
        } catch {
            lastError = "登録情報の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    func persist() {
        do {
            let metadata = items.map(ProfileItemMetadata.init)
            let data = try JSONEncoder.appDefault.encode(metadata)
            try data.write(to: metadataURL, options: [.atomic])

            var values: [String: String] = [:]
            for item in items { values[item.id.uuidString] = item.value }
            try keychain.saveAll(values)
            lastError = nil
        } catch {
            lastError = "登録情報の保存に失敗しました: \(error.localizedDescription)"
        }
    }
}

extension JSONEncoder {
    static var appDefault: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var appDefault: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
