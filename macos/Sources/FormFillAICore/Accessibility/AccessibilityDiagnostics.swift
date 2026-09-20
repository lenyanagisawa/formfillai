import AppKit
import ApplicationServices
import Foundation

/// フォーカス取得に失敗したときの切り分け情報。
/// 権限の問題か、アプリが画面の中身を公開していないだけかを見分けるために使う。
/// 値は読まず、役割と属性の有無だけを記録する。
extension AccessibilityService {

    public static func focusDiagnostics() -> String {
        var parts = ["trusted=\(AXIsProcessTrusted())"]

        if let app = NSWorkspace.shared.frontmostApplication {
            parts.append("frontmost=\(app.localizedName ?? "?")/\(app.bundleIdentifier ?? "?")")
            parts.append(contentsOf: describe(app: app))
        } else {
            parts.append("frontmost=nil")
        }

        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 1.0)
        parts.append("sysApp=\(errorName(rawError(systemWide, kAXFocusedApplicationAttribute)))")
        parts.append("sysFocus=\(errorName(rawError(systemWide, kAXFocusedUIElementAttribute)))")
        return parts.joined(separator: " ")
    }

    private static func describe(app: NSRunningApplication) -> [String] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 1.0)

        var parts = ["appFocusErr=\(errorName(rawError(appElement, kAXFocusedUIElementAttribute)))"]

        let element = copyElement(appElement, kAXFocusedUIElementAttribute)
        parts.append("appFocus=\(element != nil)")
        if let element {
            parts.append("role=\(role(of: element) ?? "nil")")
            parts.append("subrole=\(string(element, kAXSubroleAttribute) ?? "nil")")
            parts.append("secure=\(isSecure(element))")
            parts.append("textInput=\(isTextInput(element))")
        }

        let window = copyElement(appElement, kAXFocusedWindowAttribute)
        parts.append("appWindow=\(window != nil)")
        if let window {
            parts.append("winFocus=\(copyElement(window, kAXFocusedUIElementAttribute) != nil)")
            // 1〜2 しか無ければ、アプリが画面の中身をまだ公開していない。
            parts.append("winChildren=\(copyElements(window, kAXChildrenAttribute).count)")
            parts.append("treeFocus=\(findFocusedDescendant(in: window, depth: 8) != nil)")
        }
        parts.append("appChildren=\(copyElements(appElement, kAXChildrenAttribute).count)")
        return parts
    }

    private static func rawError(_ element: AXUIElement, _ attribute: String) -> AXError {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    }

    private static func errorName(_ error: AXError) -> String {
        switch error {
        case .success: return "success"
        case .failure: return "failure"
        case .illegalArgument: return "illegalArgument"
        case .invalidUIElement: return "invalidUIElement"
        case .cannotComplete: return "cannotComplete"
        case .attributeUnsupported: return "attributeUnsupported"
        case .notImplemented: return "notImplemented"
        case .apiDisabled: return "apiDisabled(権限なし)"
        case .noValue: return "noValue"
        default: return "other(\(error.rawValue))"
        }
    }
}
