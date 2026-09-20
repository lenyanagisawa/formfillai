import AppKit
import ApplicationServices
import Foundation

/// フォーカス中の要素から Jev へ渡す Context を組み立てる。
/// 現在入力されている value は一切読み取らない。
public enum FieldContextExtractor {

    public enum ExtractionError: LocalizedError {
        case secureField
        case notTextInput

        public var errorDescription: String? {
            switch self {
            case .secureField: return "パスワード欄では動作しません"
            case .notTextInput: return "テキストを入力できる欄ではありません"
            }
        }
    }

    public static func extract(from element: AXUIElement) throws -> FieldContext {
        guard !AccessibilityService.isSecure(element) else { throw ExtractionError.secureField }
        guard AccessibilityService.isTextInput(element) else { throw ExtractionError.notTextInput }

        let ancestors = ancestorChain(of: element, limit: 8)

        return FieldContext(
            application: applicationInfo(for: element),
            window: FieldContext.Window(title: windowTitle(for: element, ancestors: ancestors)),
            page: pageInfo(ancestors: ancestors),
            field: fieldInfo(element: element, ancestors: ancestors)
        )
    }

    // MARK: - Application / Window

    private static func applicationInfo(for element: AXUIElement) -> FieldContext.Application {
        guard let pid = AccessibilityService.pid(of: element),
              let app = NSRunningApplication(processIdentifier: pid)
        else {
            return FieldContext.Application(name: nil, bundleId: nil)
        }
        return FieldContext.Application(name: app.localizedName, bundleId: app.bundleIdentifier)
    }

    private static func windowTitle(for element: AXUIElement, ancestors: [AXUIElement]) -> String? {
        if let window = AccessibilityService.copyElement(element, kAXWindowAttribute),
           let title = AccessibilityService.string(window, kAXTitleAttribute) {
            return title
        }
        for ancestor in ancestors where AccessibilityService.role(of: ancestor) == kAXWindowRole {
            if let title = AccessibilityService.string(ancestor, kAXTitleAttribute) { return title }
        }
        return nil
    }

    // MARK: - Page（ブラウザの場合のみ）

    private static func pageInfo(ancestors: [AXUIElement]) -> FieldContext.Page? {
        for ancestor in ancestors {
            let role = AccessibilityService.role(of: ancestor)
            guard role == "AXWebArea" else { continue }

            let title = AccessibilityService.string(ancestor, kAXTitleAttribute)
            var domain: String?
            if let url: URL = AccessibilityService.copy(ancestor, kAXURLAttribute) {
                domain = url.host
            } else if let urlString = AccessibilityService.string(ancestor, kAXURLAttribute) {
                domain = URL(string: urlString)?.host
            }
            guard domain != nil || title != nil else { continue }
            return FieldContext.Page(domain: domain, title: title)
        }
        return nil
    }

    // MARK: - Field

    private static func fieldInfo(element: AXUIElement, ancestors: [AXUIElement]) -> FieldContext.Field {
        let position = siblingPosition(of: element)
        var title = AccessibilityService.string(element, kAXTitleAttribute)

        // Web フォームではラベルが AXTitleUIElement 経由で紐づくことが多い。
        if title == nil, let labelElement = AccessibilityService.copyElement(element, kAXTitleUIElementAttribute) {
            title = AccessibilityService.string(labelElement, kAXValueAttribute)
                ?? AccessibilityService.string(labelElement, kAXTitleAttribute)
                ?? AccessibilityService.string(labelElement, kAXDescriptionAttribute)
        }

        return FieldContext.Field(
            role: AccessibilityService.role(of: element),
            subrole: AccessibilityService.string(element, kAXSubroleAttribute),
            title: title,
            placeholder: AccessibilityService.string(element, kAXPlaceholderValueAttribute),
            description: AccessibilityService.string(element, kAXDescriptionAttribute),
            help: AccessibilityService.string(element, kAXHelpAttribute),
            nearbyTexts: nearbyTexts(element: element, ancestors: ancestors),
            siblingIndex: position?.index,
            siblingCount: position?.count
        )
    }

    /// 同じ親の下に並ぶ同種の入力欄の中での位置。
    ///
    /// 郵便番号 2 ボックス・電話 3 ボックスのような分割入力を判別するために使う。
    /// フォーム全体が同じ親にぶら下がっている場合は「20 個中 7 番目」のような
    /// 意味のない情報になるため、5 個以上並ぶときは手がかりとして扱わない。
    static func siblingPosition(of element: AXUIElement) -> (index: Int, count: Int)? {
        guard let parent = AccessibilityService.parent(of: element),
              let role = AccessibilityService.role(of: element)
        else { return nil }

        let siblings = AccessibilityService.children(of: parent)
            .filter { AccessibilityService.role(of: $0) == role }
        guard (2...4).contains(siblings.count),
              let index = siblings.firstIndex(where: { CFEqual($0, element) })
        else { return nil }

        return (index + 1, siblings.count)
    }

    // MARK: - 周辺テキスト

    private static let maxNearbyTexts = 10
    private static let maxVisitedNodes = 300
    private static let maxTextLength = 80

    /// 入力欄の周辺にある静的テキストを、近い順に収集する。
    static func nearbyTexts(element: AXUIElement, ancestors: [AXUIElement]) -> [String] {
        var collected: [String] = []
        var seen = Set<String>()
        var visited = 0

        func addText(_ text: String?) {
            guard let text else { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= maxTextLength else { return }
            guard seen.insert(trimmed).inserted else { return }
            collected.append(trimmed)
        }

        /// ある要素の配下から静的テキストを集める。深さ制限つき。
        func collectDescendants(_ root: AXUIElement, depth: Int) {
            guard depth >= 0, collected.count < maxNearbyTexts, visited < maxVisitedNodes else { return }
            for child in AccessibilityService.children(of: root) {
                visited += 1
                guard collected.count < maxNearbyTexts, visited < maxVisitedNodes else { return }
                let role = AccessibilityService.role(of: child)
                if role == kAXStaticTextRole {
                    addText(AccessibilityService.string(child, kAXValueAttribute)
                        ?? AccessibilityService.string(child, kAXTitleAttribute))
                } else if role == kAXTextFieldRole || role == kAXTextAreaRole {
                    // 別の入力欄のラベル的な情報のみ拾う。値は読まない。
                    addText(AccessibilityService.string(child, kAXDescriptionAttribute))
                } else {
                    addText(AccessibilityService.string(child, kAXTitleAttribute))
                    collectDescendants(child, depth: depth - 1)
                }
            }
        }

        // 近い祖先から順に広げる。
        for (index, ancestor) in ancestors.prefix(3).enumerated() {
            guard collected.count < maxNearbyTexts else { break }
            collectDescendants(ancestor, depth: index + 1)
        }
        return collected
    }

    // MARK: - 祖先チェーン

    static func ancestorChain(of element: AXUIElement, limit: Int) -> [AXUIElement] {
        var chain: [AXUIElement] = []
        var current = element
        for _ in 0..<limit {
            guard let parent = AccessibilityService.parent(of: current) else { break }
            chain.append(parent)
            current = parent
        }
        return chain
    }
}
