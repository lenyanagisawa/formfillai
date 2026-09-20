import ApplicationServices
import Foundation

/// フォーカス中の入力欄を、AX ツリーの構築待ちも含めて取得する。
public enum FocusResolver {

    /// Chromium / Electron は AX ツリーを非同期に組み立てるため、
    /// 取れなければ間隔を空けながら数回試す（合計 約 1.6 秒）。
    private static let retryDelaysMs = [150, 300, 500, 700]

    /// - Parameter onWaiting: 1 回目で取れず待ちに入るときに呼ばれる。UI に待機中を出すため。
    @MainActor
    public static func resolve(onWaiting: () -> Void) async -> AXUIElement? {
        if let element = AccessibilityService.focusedElement() { return element }

        onWaiting()
        for delay in retryDelaysMs {
            try? await Task.sleep(for: .milliseconds(delay))
            if let element = AccessibilityService.focusedElement() { return element }
        }
        return nil
    }
}
