import Foundation

/// 用意済みフォームからの読み書き。空欄は「未登録」として扱う。
extension ProfileStore {

    public func value(for field: ProfileTemplate.Field) -> String {
        items.first { $0.label == field.label }?.value ?? ""
    }

    /// 値を入れれば登録、空にすれば削除。種類は常にフォームの定義に合わせる。
    public func setValue(_ rawValue: String, for field: ProfileTemplate.Field) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let index = items.firstIndex { $0.label == field.label }

        switch (index, value.isEmpty) {
        case (let index?, true):
            items.remove(at: index)
        case (let index?, false):
            guard items[index].value != value || items[index].semanticType != field.semanticType else { return }
            items[index].value = value
            items[index].semanticType = field.semanticType
            items[index].updatedAt = Date()
        case (nil, true):
            return
        case (nil, false):
            guard canAddMore else {
                reportError("登録できるのは \(ProfileItem.maxCount) 件までです")
                return
            }
            items.append(ProfileItem(label: field.label, value: value, semanticType: field.semanticType))
        }
        normalizeOrder()
        persist()
    }

    /// 1 つ目のセット → 追加セット → 自分で足した項目、の順に揃える。
    /// 候補数が上限を超えたときに切り捨てられるのは後ろからなので、よく使うものを前に置く。
    func normalizeOrder() {
        let extraSets = ProfileTemplate.extraSetNames(in: items)
        let last = (2, 0, 0)
        items.sort { lhs, rhs in
            let left = ProfileTemplate.orderKey(for: lhs.label, extraSets: extraSets) ?? last
            let right = ProfileTemplate.orderKey(for: rhs.label, extraSets: extraSets) ?? last
            return left != right ? left < right : lhs.sortOrder < rhs.sortOrder
        }
        for index in items.indices { items[index].sortOrder = index }
    }

    // MARK: - 2 つ目以降のセット

    /// セットの名前を変える。項目名の接頭辞を付け替えるだけで、値はそのまま。
    public func renameSet(_ oldName: String, to newName: String, in section: ProfileTemplate.Section) {
        for index in items.indices {
            guard let parsed = ProfileTemplate.parseScoped(items[index].label),
                  parsed.section.id == section.id, parsed.setName == oldName else { continue }
            items[index].label = ProfileTemplate.scopedLabel(parsed.field.label, setName: newName)
            items[index].updatedAt = Date()
        }
        persist()
    }

    public func deleteSet(_ name: String, in section: ProfileTemplate.Section) {
        items.removeAll { item in
            guard let parsed = ProfileTemplate.parseScoped(item.label) else { return false }
            return parsed.section.id == section.id && parsed.setName == name
        }
        normalizeOrder()
        persist()
    }

    public var customItems: [ProfileItem] { items.filter(ProfileTemplate.isCustom) }
}
