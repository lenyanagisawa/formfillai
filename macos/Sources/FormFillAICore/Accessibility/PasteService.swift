import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// 選択された最終値を対象フィールドへ入力する。
///
/// React などの Controlled Input でも change イベントが発火するよう、
/// AX で値を直接書き込まず「全選択 → Cmd+V」で置換する。
@MainActor
public final class PasteService {

    /// ショートカット押下時点の入力先。UI を出す前に必ず捕まえておく。
    public struct Target {
        public let element: AXUIElement
        public let app: NSRunningApplication?

        public init(element: AXUIElement, app: NSRunningApplication?) {
            self.element = element
            self.app = app
        }
    }

    public enum PasteError: LocalizedError {
        case noAccessibilityPermission

        public var errorDescription: String? { "アクセシビリティ権限がありません" }
    }

    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    private enum KeyCode {
        static let a: CGKeyCode = 0x00
        static let v: CGKeyCode = 0x09
    }

    private enum Delay {
        /// 対象アプリが前面に戻るのを待つ。
        static let afterActivate = 80
        /// フォーカス復元 → 全選択 → ペーストの各キー入力の間隔。
        static let betweenKeys = 20
        /// 対象アプリがクリップボードを読み終えるまでの猶予。
        static let beforeRestore = 300
    }

    /// 借りているクリップボードの、元の中身と返却タスク。
    private var borrowed: (snapshot: PasteboardSnapshot, restore: Task<Void, Never>)?

    public init() {}

    /// Cmd+V を送った時点で戻る。クリップボードの復元は裏で行うので、呼び出し側を待たせない。
    public func paste(_ value: String, into target: Target) async throws {
        guard AccessibilityService.isTrusted else { throw PasteError.noAccessibilityPermission }

        let pasteboard = NSPasteboard.general

        // 前回の返却が終わる前に次の入力が来たら、元の中身は前回のスナップショットにある。
        // ここで取り直すと「前回入力した値」を元の中身だと誤認してしまう。
        let snapshot: PasteboardSnapshot
        if let borrowed {
            borrowed.restore.cancel()
            snapshot = borrowed.snapshot
        } else {
            snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        }

        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        // クリップボード履歴アプリに、個人情報やカード番号を記録させない。
        // nspasteboard.org の慣習で、対応アプリ（Raycast, Alfred, Maccy, Paste など）はこの印が付いた内容を無視する。
        pasteboard.setString("", forType: Self.concealedType)
        pasteboard.setString("", forType: Self.transientType)
        let changeCountAfterWrite = pasteboard.changeCount

        // 候補 UI を操作した後は、対象アプリを前面に戻す必要がある。
        if let app = target.app, !app.isActive {
            app.activate()
            try? await Task.sleep(for: .milliseconds(Delay.afterActivate))
        }
        AXUIElementSetAttributeValue(target.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        try? await Task.sleep(for: .milliseconds(Delay.betweenKeys))

        // 既存値は追記ではなく置換する。
        sendKey(KeyCode.a, flags: .maskCommand)
        try? await Task.sleep(for: .milliseconds(Delay.betweenKeys))
        sendKey(KeyCode.v, flags: .maskCommand)

        let restore = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Delay.beforeRestore))
            guard !Task.isCancelled else { return }
            // 処理中にユーザーが別の内容をコピーしていたら、それを壊さない。
            if pasteboard.changeCount == changeCountAfterWrite {
                snapshot.restore(to: pasteboard)
            }
            self?.borrowed = nil
        }
        borrowed = (snapshot, restore)
    }

    private func sendKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

/// 元のクリップボード内容を保持して復元する。
struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            var stored: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { stored[type] = data }
            }
            return stored
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let restored = items.map { stored -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in stored { item.setData(data, forType: type) }
            return item
        }
        pasteboard.writeObjects(restored)
    }
}
