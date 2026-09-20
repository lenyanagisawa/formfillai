import CryptoKit
import Foundation

/// 入力欄を識別するハッシュ。ログ上で「自動入力 → 違うで修正」を同じ欄の出来事として結びつけるために使う。
public enum FieldSignature {

    public static func make(from context: FieldContext) -> String {
        let components: [String] = [
            context.application.bundleId ?? "",
            context.page?.domain ?? "",
            context.field.role ?? "",
            normalize(context.field.title),
            normalize(context.field.placeholder),
            normalize(context.field.description),
            // 郵便番号 2 ボックスのように属性が同一の欄を区別する。
            context.field.siblingIndex.map(String.init) ?? "",
            // 主要な周辺テキストのみ。多すぎると署名が不安定になる。
            primaryNearbyTexts(context.field.nearbyTexts).joined(separator: "\u{1F}"),
        ]
        let joined = components.joined(separator: "\u{1E}")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func primaryNearbyTexts(_ texts: [String]) -> [String] {
        Array(texts.map(normalize).filter { !$0.isEmpty }.prefix(3))
    }

    /// 空白差や全角半角差で署名が割れないように正規化する。
    static func normalize(_ value: String?) -> String {
        guard let value else { return "" }
        let folded = value.folding(options: [.widthInsensitive, .caseInsensitive], locale: nil)
        return folded
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
