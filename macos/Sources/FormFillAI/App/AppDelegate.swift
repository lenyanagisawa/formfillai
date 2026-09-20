import AppKit
import FormFillAICore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?

    private let profileStore = ProfileStore()
    private let settings = AppSettings()
    private let log = DebugLog()
    private let hotKey = HotKeyService()
    private let classifier = ClassifierClient()
    private var accessibilityBoost: AccessibilityBoost!

    private var coordinator: FillCoordinator!
    private var panelController: FillPanelController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator = FillCoordinator(
            profileStore: profileStore,
            settings: settings,
            classifier: classifier,
            log: log
        )
        panelController = FillPanelController(coordinator: coordinator, profileStore: profileStore)

        setUpStatusItem()

        // Option + Space。バックグラウンドでも動作する。
        hotKey.register { [weak self] in
            self?.coordinator.trigger()
        }

        // 初回起動時に権限を要求する。
        if !AccessibilityService.isTrusted {
            AccessibilityService.requestPermission()
        }

        // アプリが前面に出るたびに、AX ツリーの有効化と通信の暖機を済ませておく。
        // ショートカットを押してから始めたのでは間に合わない。
        accessibilityBoost = AccessibilityBoost { [classifier, settings] in
            classifier.warmUpIfNeeded(settings: settings)
        }
        accessibilityBoost.start()

        // 未設定なら設定画面を開いて気づけるようにする。
        if profileStore.items.isEmpty || !settings.isConfigured {
            openMainWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey.unregister()
        accessibilityBoost.stop()
    }

    // MARK: - メニューバー

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "text.insert",
            accessibilityDescription: "FormFillAI"
        )
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(withTitle: "入力する（⌥Space）", action: #selector(triggerFill), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "登録情報と設定…", action: #selector(openMainWindow), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())

        let status = NSMenuItem(
            title: AccessibilityService.isTrusted ? "アクセシビリティ権限: 許可済み" : "アクセシビリティ権限: 未許可",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        status.target = self
        menu.addItem(status)

        menu.addItem(.separator())
        menu.addItem(withTitle: "FormFillAI を終了", action: #selector(quit), keyEquivalent: "q")
            .target = self

        item.menu = menu
        statusItem = item
    }

    @objc private func triggerFill() {
        coordinator.trigger()
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityService.openAccessibilitySettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - メインウィンドウ

    @objc func openMainWindow() {
        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = MainWindowView(
            store: profileStore,
            settings: settings,
            log: log
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FormFillAI"
        window.contentView = NSHostingView(rootView: rootView)
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow = window
    }
}
