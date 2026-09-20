import FormFillAICore
import SwiftUI

/// 登録情報のフォーム。用意された欄に値を入れていくだけで登録が完結する。
/// 入力は自動保存され、空欄は未登録として扱われる。
struct ProfileFormView: View {
    @ObservedObject var store: ProfileStore

    /// 保存前の入力内容。打鍵のたびに Keychain へ書かないよう、少し待ってから保存する。
    @State private var drafts: [String: String] = [:]
    @State private var pendingSaves: [String: Task<Void, Never>] = [:]
    @State private var editingCustom: EditingItem?
    /// 既定では出していないセクション（自宅など）のうち、ユーザーが追加したもの。
    @State private var revealedSections: Set<String> = []
    /// 作ったばかりでまだ値が無いセット。値が入れば登録済みの項目名から復元できるので、保持は画面の間だけでよい。
    @State private var emptySets: [String: [String]] = [:]
    @State private var namingSet: SetNaming?

    private static let saveDelay: Duration = .milliseconds(600)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(visibleSections) { section in
                        sectionView(section)
                    }
                    if !hiddenSections.isEmpty { addSectionRow }
                    customSection
                }
                .padding(16)
            }
        }
        .onAppear(perform: loadDrafts)
        .onDisappear(perform: flushPendingSaves)
        .sheet(item: $namingSet) { naming in
            SetNameSheet(naming: naming) { name in
                if let name { applySetName(name, for: naming) }
                namingSet = nil
            }
        }
        .sheet(item: $editingCustom) { editing in
            ProfileItemForm(store: store, existing: editing.item) { editingCustom = nil }
        }
    }

    // MARK: - ヘッダ

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("使いそうな欄だけ埋めてください")
                    .font(.system(size: 12, weight: .medium))
                Text("入力すると自動で保存されます。空欄のままの項目は登録されません。")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let error = store.lastError {
                Text(error).font(.system(size: 10)).foregroundStyle(.red).lineLimit(2)
            }
            Text("\(store.items.count) / \(ProfileItem.maxCount)")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - セクションの出し分け

    /// 既定のセクションと、値が入っているか追加されたセクション。
    private var visibleSections: [ProfileTemplate.Section] {
        ProfileTemplate.sections.filter { section in
            section.isDefault || revealedSections.contains(section.id)
                || section.fields.contains { !(drafts[$0.label] ?? "").isEmpty }
                || !setNames(in: section).isEmpty
        }
    }

    private var hiddenSections: [ProfileTemplate.Section] {
        let visible = Set(visibleSections.map(\.id))
        return ProfileTemplate.sections.filter { !visible.contains($0.id) }
    }

    private var addSectionRow: some View {
        HStack(spacing: 8) {
            ForEach(hiddenSections) { section in
                Button {
                    revealedSections.insert(section.id)
                } label: {
                    Label("\(section.title)を追加", systemImage: section.symbol)
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: - 用意済みの欄

    private func sectionView(_ section: ProfileTemplate.Section) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: section.symbol).foregroundStyle(.secondary)
                Text(section.title).font(.system(size: 12, weight: .semibold))
                Text(filledCount(section.fields))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            fieldGroup(section.fields)

            ForEach(setNames(in: section), id: \.self) { setName in
                extraSetView(setName, in: section)
            }

            Button {
                namingSet = SetNaming(section: section, renaming: nil)
            } label: {
                Label("\(section.title)をもう1つ追加", systemImage: "plus")
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(Color.accentColor)
        }
    }

    private func extraSetView(_ setName: String, in section: ProfileTemplate.Section) -> some View {
        let fields = section.fields.map { $0.scoped(to: setName) }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(setName).font(.system(size: 11, weight: .semibold))
                Text(filledCount(fields)).font(.system(size: 10).monospacedDigit()).foregroundStyle(.tertiary)
                Spacer()
                Menu {
                    Button("名前を変更…") { namingSet = SetNaming(section: section, renaming: setName) }
                    Button("このセットを削除", role: .destructive) { deleteSet(setName, in: section) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            fieldGroup(fields)
        }
        .padding(.leading, 12)
    }

    private func fieldGroup(_ fields: [ProfileTemplate.Field]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
                if index > 0 { Divider().padding(.leading, 12) }
                ProfileFieldRow(field: field, text: binding(for: field))
            }
        }
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func filledCount(_ fields: [ProfileTemplate.Field]) -> String {
        "\(fields.filter { !(drafts[$0.label] ?? "").isEmpty }.count)/\(fields.count)"
    }

    // MARK: - 2 つ目以降のセット

    /// 登録済みの項目名から分かるセットに、作ったばかりの空のセットを足したもの。
    private func setNames(in section: ProfileTemplate.Section) -> [String] {
        var names = ProfileTemplate.extraSetNames(in: store.items)[section.id] ?? []
        for name in emptySets[section.id] ?? [] where !names.contains(name) { names.append(name) }
        return names
    }

    private func applySetName(_ name: String, for naming: SetNaming) {
        let section = naming.section
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: String(ProfileTemplate.setSeparator), with: "")
        guard !trimmed.isEmpty, !setNames(in: section).contains(trimmed) else { return }

        flushPendingSaves()
        if let oldName = naming.renaming {
            store.renameSet(oldName, to: trimmed, in: section)
            emptySets[section.id] = (emptySets[section.id] ?? []).map { $0 == oldName ? trimmed : $0 }
            loadDrafts()
        } else {
            emptySets[section.id, default: []].append(trimmed)
        }
    }

    private func deleteSet(_ name: String, in section: ProfileTemplate.Section) {
        flushPendingSaves()
        store.deleteSet(name, in: section)
        emptySets[section.id]?.removeAll { $0 == name }
        loadDrafts()
    }

    // MARK: - 自分で足した項目

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "plus.square.on.square").foregroundStyle(.secondary)
                Text("その他の項目").font(.system(size: 12, weight: .semibold))
            }
            if !store.customItems.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(store.customItems.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().padding(.leading, 12) }
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.label).font(.system(size: 12, weight: .medium))
                                Text(item.value).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button("編集") { editingCustom = EditingItem(item: item) }.controlSize(.small)
                            Button("削除", role: .destructive) { store.delete(item) }.controlSize(.small)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                    }
                }
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            HStack(spacing: 8) {
                Button {
                    editingCustom = EditingItem(item: nil)
                } label: {
                    Label("フォームに無い項目を追加", systemImage: "plus")
                }
                .disabled(!store.canAddMore)

                Button {
                    flushPendingSaves()
                    ProfileImportFlow.run(store: store)
                    loadDrafts()
                } label: {
                    Label("JSONから一括登録", systemImage: "square.and.arrow.down")
                }
            }
            .controlSize(.small)
        }
    }

    // MARK: - 下書きと自動保存

    private func loadDrafts() {
        drafts = Dictionary(uniqueKeysWithValues: allVisibleFields.map { ($0.label, store.value(for: $0)) })
    }

    /// 1 つ目のセットと、追加セットのすべての欄。
    private var allVisibleFields: [ProfileTemplate.Field] {
        ProfileTemplate.sections.flatMap { section in
            section.fields + setNames(in: section).flatMap { name in section.fields.map { $0.scoped(to: name) } }
        }
    }

    private func binding(for field: ProfileTemplate.Field) -> Binding<String> {
        Binding(
            get: { drafts[field.label] ?? "" },
            set: { newValue in
                drafts[field.label] = newValue
                scheduleSave(field)
            }
        )
    }

    private func scheduleSave(_ field: ProfileTemplate.Field) {
        pendingSaves[field.label]?.cancel()
        pendingSaves[field.label] = Task {
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            store.setValue(drafts[field.label] ?? "", for: field)
            pendingSaves[field.label] = nil
        }
    }

    /// ウインドウを閉じる直前など、待ち時間中の入力を取りこぼさないようにする。
    private func flushPendingSaves() {
        for (label, task) in pendingSaves {
            task.cancel()
            if let field = allVisibleFields.first(where: { $0.label == label }) {
                store.setValue(drafts[label] ?? "", for: field)
            }
        }
        pendingSaves.removeAll()
    }
}

/// フォームの 1 行。入力した値から自動で用意される候補を、その場で見せる。
private struct ProfileFieldRow: View {
    let field: ProfileTemplate.Field
    @Binding var text: String
    @FocusState private var isFocused: Bool

    private var showsMask: Bool { field.isSensitive && !isFocused && !text.isEmpty }

    /// 登録値のほかに自動生成される表記（法人格なし、分割、全角など）。機密欄では出さない。
    private var generatedValues: [String] {
        guard !field.isSensitive else { return [] }
        let draft = ProfileItem(label: field.label, value: text, semanticType: field.semanticType)
        return VirtualCandidateBuilder.build(from: draft)
            .filter { $0.variant != .raw }
            .map { ValueTransformer.apply($0.variant, to: text) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(field.title)
                    .font(.system(size: 12))
                    .frame(width: 132, alignment: .leading)
                ZStack(alignment: .leading) {
                    TextField(field.placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($isFocused)
                        // 機密欄は入力中だけ素の値を見せ、それ以外は伏せた表示を重ねる。
                        .opacity(showsMask ? 0 : 1)
                    if showsMask {
                        Text(ValueTransformer.masked(text))
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .allowsHitTesting(false)
                    }
                }
                if !text.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green.opacity(0.8))
                }
            }
            if isFocused, let hint = field.hint {
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 142)
            }
            if !generatedValues.isEmpty {
                Text("自動: " + generatedValues.joined(separator: "  /  "))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 142)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }
}

/// セットに名前を付ける対象。renaming が nil なら新規作成。
struct SetNaming: Identifiable {
    let id = UUID()
    let section: ProfileTemplate.Section
    let renaming: String?
}

/// 2 つ目以降のセットの名前を決める。この名前が Jev にとって 1 つ目との唯一の区別になる。
private struct SetNameSheet: View {
    let naming: SetNaming
    let onFinish: (String?) -> Void
    @State private var name: String

    init(naming: SetNaming, onFinish: @escaping (String?) -> Void) {
        self.naming = naming
        self.onFinish = onFinish
        _name = State(initialValue: naming.renaming ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(naming.renaming == nil ? "\(naming.section.title)をもう1つ追加" : "名前を変更")
                .font(.system(size: 13, weight: .semibold))
            TextField("例: \(naming.section.setNameExample)", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { onFinish(name) }
            Text("1つ目と区別するための名前です。入力欄に手がかりが無いときは1つ目が入り、「違う」を押すとこちらに切り替えられます。")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("キャンセル") { onFinish(nil) }
                Button(naming.renaming == nil ? "追加" : "変更") { onFinish(name) }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 360)
    }
}
