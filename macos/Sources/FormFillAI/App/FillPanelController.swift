import AppKit
import Combine
import FormFillAICore
import SwiftUI

/// 入力欄のそばに出すフローティングパネル。
///
/// `.nonactivatingPanel` にすることで、このパネルを表示しても
/// 対象アプリのフォーカスが外れない。
@MainActor
final class FillPanelController {

    private let coordinator: FillCoordinator
    private let profileStore: ProfileStore
    private var panel: NSPanel?
    private var cancellable: AnyCancellable?

    init(coordinator: FillCoordinator, profileStore: ProfileStore) {
        self.coordinator = coordinator
        self.profileStore = profileStore
        cancellable = coordinator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.update(for: state) }
    }

    private func update(for state: FillState) {
        if case .idle = state {
            hide()
            return
        }
        show()
    }

    private func show() {
        let panel = panel ?? makePanel()
        self.panel = panel

        panel.layoutIfNeeded()
        panel.setFrameOrigin(preferredOrigin(for: panel.frame.size))
        panel.orderFrontRegardless()

        // 状態が変わると SwiftUI 側の高さも変わる。
        // 確定した高さで置き直さないと、画面端で見切れることがある。
        DispatchQueue.main.async { [weak panel] in
            guard let panel, panel.isVisible else { return }
            panel.setFrameOrigin(self.preferredOrigin(for: panel.frame.size))
        }
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let rootView = FillOverlayView(
            coordinator: coordinator,
            resolveValue: { [weak self] candidate in
                self?.profileStore.displayValue(for: candidate)
            }
        )
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // NSHostingController にすると、SwiftUI の内容に合わせて
        // パネルの高さが自動で追従する。
        panel.contentViewController = NSHostingController(rootView: rootView)
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return panel
    }

    /// 入力欄の真下に出す。取得できなければマウス位置にフォールバックする。
    private func preferredOrigin(for size: NSSize) -> NSPoint {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var origin: NSPoint
        if let fieldFrame = coordinator.targetFieldFrame,
           let primaryMaxY = NSScreen.screens.first?.frame.maxY {
            // AX 座標は左上原点。Cocoa の左下原点へ変換する。
            let fieldBottomInCocoa = primaryMaxY - fieldFrame.maxY
            origin = NSPoint(x: fieldFrame.minX, y: fieldBottomInCocoa - size.height - 8)
        } else {
            let mouse = NSEvent.mouseLocation
            origin = NSPoint(x: mouse.x, y: mouse.y - size.height - 12)
        }

        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        return origin
    }
}
