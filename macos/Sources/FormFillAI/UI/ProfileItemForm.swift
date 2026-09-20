import FormFillAICore
import SwiftUI

struct EditingItem: Identifiable {
    let id = UUID()
    let item: ProfileItem?
}

/// 追加・編集フォーム。
struct ProfileItemForm: View {
    @ObservedObject var store: ProfileStore
    let existing: ProfileItem?
    let onClose: () -> Void

    @State private var semanticType: SemanticType
    @State private var label: String
    @State private var value: String

    init(store: ProfileStore, existing: ProfileItem?, onClose: @escaping () -> Void) {
        self.store = store
        self.existing = existing
        self.onClose = onClose
        _semanticType = State(initialValue: existing?.semanticType ?? .custom)
        _label = State(initialValue: existing?.label ?? "")
        _value = State(initialValue: existing?.value ?? "")
    }

    private var previewCandidates: [VirtualCandidate] {
        let draft = ProfileItem(label: label.isEmpty ? semanticType.defaultLabel : label,
                                value: value, semanticType: semanticType)
        return VirtualCandidateBuilder.build(from: draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(existing == nil ? "フォームに無い項目を追加" : "項目を編集")
                .font(.system(size: 13, weight: .semibold))

            Form {
                Picker("種類", selection: $semanticType) {
                    ForEach(SemanticType.presets, id: \.self) { type in
                        Text(type.defaultLabel).tag(type)
                    }
                }
                .onChange(of: semanticType) { _, newValue in
                    // プリセットを選んだら項目名も追従させる（自由入力済みなら尊重する）。
                    if label.isEmpty || SemanticType.allCases.contains(where: { $0.defaultLabel == label }) {
                        label = newValue.defaultLabel
                    }
                }

                TextField("項目名", text: $label)
                TextField("値", text: $value)
            }
            .formStyle(.grouped)

            if previewCandidates.count > 1 {
                VStack(alignment: .leading, spacing: 3) {
                    Text("生成される入力候補")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    ForEach(previewCandidates) { candidate in
                        Text("・\(candidate.label)：\(ValueTransformer.apply(candidate.variant, to: value))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }

            HStack {
                Spacer()
                Button("キャンセル", action: onClose)
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty
                        || value.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    private func save() {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing {
            store.update(existing, label: trimmedLabel, value: trimmedValue, semanticType: semanticType)
        } else {
            store.add(label: trimmedLabel, value: trimmedValue, semanticType: semanticType)
        }
        onClose()
    }
}
