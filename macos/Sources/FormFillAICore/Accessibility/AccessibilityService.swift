import AppKit
import ApplicationServices
import Foundation

/// Accessibility API の薄いラッパ。
public enum AccessibilityService {

    // MARK: - 権限

    public static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// 初回起動時などに権限ダイアログを出す。
    @discardableResult
    public static func requestPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - フォーカス取得

    /// 現在フォーカスされている UI 要素。
    public static func focusedElement() -> AXUIElement? {
        // 前面アプリから直接たどる。
        // system-wide 要素の AXFocusedApplication は環境によって noValue を返すため、
        // NSWorkspace が教えてくれる前面アプリを起点にするほうが確実。
        if let app = NSWorkspace.shared.frontmostApplication {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(appElement, 1.0)

            // Chrome / Electron は明示的に要求しないと完全な AX ツリーを公開しない。
            enableEnhancedAccessibilityIfNeeded(for: appElement)

            if let element = copyElement(appElement, kAXFocusedUIElementAttribute) {
                return element
            }
            // アプリによってはフォーカス中のウインドウ経由でしか取れない。
            if let window = copyElement(appElement, kAXFocusedWindowAttribute),
               let element = copyElement(window, kAXFocusedUIElementAttribute) {
                return element
            }

            // AXFocusedUIElement を持たないアプリでも、
            // ツリーを辿れば AXFocused == true の要素が見つかることがある。
            if let window = copyElement(appElement, kAXFocusedWindowAttribute),
               let element = findFocusedDescendant(in: window, depth: 8) {
                return element
            }
        }

        // 最後の手段として system-wide 要素も試す。
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 1.0)
        if let focusedApp = copyElement(systemWide, kAXFocusedApplicationAttribute),
           let element = copyElement(focusedApp, kAXFocusedUIElementAttribute) {
            return element
        }
        return copyElement(systemWide, kAXFocusedUIElementAttribute)
    }

    /// AXFocused == true の子孫を幅優先で探す。
    /// 探索ノード数に上限を設けて、巨大な Web ページでも止まらないようにする。
    static func findFocusedDescendant(in root: AXUIElement, depth: Int) -> AXUIElement? {
        var queue: [(element: AXUIElement, level: Int)] = [(root, 0)]
        var visited = 0

        while !queue.isEmpty, visited < 800 {
            let (element, level) = queue.removeFirst()
            visited += 1

            if let focused: Bool = copy(element, kAXFocusedAttribute), focused {
                return element
            }
            guard level < depth else { continue }
            for child in children(of: element) {
                queue.append((child, level + 1))
            }
        }
        return nil
    }

    /// Chromium 系 / Electron 系アプリの AX ツリーを有効化する。
    public static func enableEnhancedAccessibilityIfNeeded(for app: AXUIElement) {
        // Electron 製アプリ（Slack, Notion, VS Code, Discord…）はバンドル ID から判別できない。
        // AXManualAccessibility は対応していないアプリでは単に無視されるので、全アプリに立てる。
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)

        // AXEnhancedUserInterface はネイティブアプリのウインドウ挙動に副作用があるため、
        // Chromium 系ブラウザに限定する。
        var pid: pid_t = 0
        guard AXUIElementGetPid(app, &pid) == .success,
              let bundleId = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        else { return }
        let chromiumBrowsers = ["com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser",
                                "company.thebrowser.Browser", "com.vivaldi.Vivaldi", "org.chromium.Chromium"]
        if chromiumBrowsers.contains(bundleId) {
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
    }

    // MARK: - 属性アクセス

    public static func copy<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? T
    }

    /// AXUIElement を取り出す。
    ///
    /// AXUIElement は Swift のクラスではなく CoreFoundation 型なので、
    /// `as? AXUIElement` は成立しない。CFTypeID で判定してから明示的に変換する。
    public static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    /// AXUIElement の配列を取り出す。要素ごとに CFTypeID を確認する。
    public static func copyElements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == CFArrayGetTypeID()
        else { return [] }

        let array = value as! CFArray
        let count = CFArrayGetCount(array)
        var result: [AXUIElement] = []
        result.reserveCapacity(count)
        for index in 0..<count {
            guard let raw = CFArrayGetValueAtIndex(array, index) else { continue }
            let item = unsafeBitCast(raw, to: CFTypeRef.self)
            guard CFGetTypeID(item) == AXUIElementGetTypeID() else { continue }
            result.append(item as! AXUIElement)
        }
        return result
    }

    public static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        guard let raw: String = copy(element, attribute) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func role(of element: AXUIElement) -> String? {
        string(element, kAXRoleAttribute)
    }

    public static func parent(of element: AXUIElement) -> AXUIElement? {
        copyElement(element, kAXParentAttribute)
    }

    public static func children(of element: AXUIElement) -> [AXUIElement] {
        copyElements(element, kAXChildrenAttribute)
    }

    public static func pid(of element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success ? pid : nil
    }

    /// 要素の画面上の位置（AX 座標系: 左上原点）。
    public static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success
        else { return nil }

        var origin = CGPoint.zero
        var size = CGSize.zero
        guard let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID(),
              AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else { return nil }

        return CGRect(origin: origin, size: size)
    }

    /// パスワード欄かどうか。
    public static func isSecure(_ element: AXUIElement) -> Bool {
        if role(of: element) == "AXSecureTextField" { return true }
        if string(element, kAXSubroleAttribute) == "AXSecureTextField" { return true }
        return false
    }

    /// テキストを入力できる要素かどうか。
    public static func isTextInput(_ element: AXUIElement) -> Bool {
        guard let role = role(of: element) else { return false }
        let textRoles: Set<String> = [
            kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole, "AXSearchField",
        ]
        if textRoles.contains(role) { return true }
        // Web のリッチテキスト欄などは AXGroup で来ることがあるため、編集可能かどうかも見る。
        // AXEditableAncestor は Bool ではなく要素を返す。
        if copyElement(element, "AXEditableAncestor") != nil { return true }
        var settable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success {
            return settable.boolValue
        }
        return false
    }
}
