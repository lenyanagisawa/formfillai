import Foundation
import FormFillAICore

enum Fixtures {
    static let items: [ProfileItem] = [
        ProfileItem(label: "会社名", value: "株式会社サンプル", semanticType: .companyName, sortOrder: 0),
        ProfileItem(label: "会社名フリガナ", value: "カブシキガイシャサンプル", semanticType: .companyNameKana, sortOrder: 1),
        ProfileItem(label: "氏名", value: "山田 太郎", semanticType: .personName, sortOrder: 2),
        ProfileItem(label: "氏名カナ", value: "ヤマダ タロウ", semanticType: .personNameKana, sortOrder: 3),
        ProfileItem(label: "郵便番号", value: "150-0001", semanticType: .postalCode, sortOrder: 4),
        ProfileItem(label: "電話番号", value: "03-1234-5678", semanticType: .phoneNumber, sortOrder: 5),
        ProfileItem(label: "メールアドレス", value: "taro@example.com", semanticType: .email, sortOrder: 6),
        ProfileItem(label: "役職", value: "代表取締役", semanticType: .jobTitle, sortOrder: 7),
        ProfileItem(label: "サービス名", value: "Sample Service", semanticType: .custom, sortOrder: 8),
    ]

    static let candidates = VirtualCandidateBuilder.build(from: items)

    ///  の代表ケース。
    static let context = FieldContext(
        application: .init(name: "Google Chrome", bundleId: "com.google.Chrome"),
        window: .init(title: "取引先情報入力"),
        page: .init(domain: "example.com", title: "会社情報"),
        field: .init(role: "AXTextField", title: "会社名フリガナ",
                     placeholder: "株式会社等の表記は除く", description: nil, help: nil,
                     nearbyTexts: ["会社名", "会社名フリガナ", "株式会社等の表記は除く"])
    )

    /// 実際に Jev へ送られる JSON。
    static var requestJSON: String { JevPrompt.request(context: context, candidates: candidates).serialized() }

    static func value(of candidate: VirtualCandidate) -> String {
        let source = items.first { $0.id == candidate.sourceProfileItemId }!
        return ValueTransformer.apply(candidate.variant, to: source.value)
    }
}
