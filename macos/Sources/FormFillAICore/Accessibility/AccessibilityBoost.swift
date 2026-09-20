import AppKit
import ApplicationServices
import Foundation

/// 前面に出たアプリに対して、使う前の下準備をする。
///
/// - Chromium / Electron 系は `AXManualAccessibility` を立てるまで画面の中身を公開しない。
///   ショートカットを押してから立てると、ツリーの構築が間に合わない。
/// - 同じタイミングで `onActivate` を呼ぶので、通信の暖機などを相乗りさせられる。
@MainActor
public final class AccessibilityBoost {

    private var observer: NSObjectProtocol?
    private var boosted = Set<pid_t>()
    private let onActivate: () -> Void

    public init(onActivate: @escaping () -> Void = {}) {
        self.onActivate = onActivate
    }

    public func start() {
        if let app = NSWorkspace.shared.frontmostApplication { prepare(app) }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
            MainActor.assumeIsolated { self?.prepare(app) }
        }
    }

    public func stop() {
        guard let observer else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(observer)
        self.observer = nil
    }

    private func prepare(_ app: NSRunningApplication) {
        onActivate()

        guard AccessibilityService.isTrusted else { return }
        // 同じプロセスに何度も立てる必要はない。
        guard boosted.insert(app.processIdentifier).inserted else { return }

        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 1.0)
        AccessibilityService.enableEnhancedAccessibilityIfNeeded(for: element)
    }
}
