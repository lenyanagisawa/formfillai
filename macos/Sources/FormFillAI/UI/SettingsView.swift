import AppKit
import FormFillAICore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var log: DebugLog

    @State private var accessibilityTrusted = AccessibilityService.isTrusted

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section("接続先") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("経路", selection: $settings.connection) {
                            ForEach(JevConnection.allCases) { Text($0.title).tag($0) }
                        }
                        Text(settings.connection.summary)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        switch settings.connection {
                        case .gateway:
                            SecureField("AI Gateway の API キー", text: $settings.credentials.gatewayKey)
                        case .typesafe:
                            SecureField("TypeSafe AI の API キー", text: $settings.credentials.typesafeKey)
                        case .relay:
                            TextField("https://your-relay.example.com/api/evaluate", text: $settings.credentials.relayURL)
                            SecureField("中継サーバーのトークン", text: $settings.credentials.relayToken)
                        }

                        Text("キーとトークンは Keychain に保存されます。どの経路でも、登録した値そのものは送信されません。送られるのは項目名と、入力欄のラベルや周辺テキストだけです。")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                section("自動入力") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("常に自動入力する", isOn: $settings.alwaysAutoPaste)
                        Text("確率に関わらず、まず一番可能性の高い候補を入力します。違っていれば「違う」を押して選び直せます。")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        Divider().padding(.vertical, 2)

                        HStack {
                            Text("自動入力のしきい値")
                            Spacer()
                            Text(String(format: "%.2f", settings.autoPasteThreshold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.autoPasteThreshold, in: 0.30...0.99, step: 0.01)
                            .disabled(settings.alwaysAutoPaste)
                        Text(settings.alwaysAutoPaste
                             ? "「常に自動入力する」がオンの間は使われません。"
                             : "選択された候補の確率がこの値以上のときだけ自動入力します。未満のときは候補を表示します。")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("タイムアウト")
                            Spacer()
                            Text(String(format: "%.1f 秒", settings.requestTimeout))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.requestTimeout, in: 1.0...8.0, step: 0.5)
                    }
                }

                section("権限") {
                    HStack {
                        Image(systemName: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(accessibilityTrusted ? .green : .orange)
                        Text(accessibilityTrusted ? "アクセシビリティ権限あり" : "アクセシビリティ権限がありません")
                            .font(.system(size: 12))
                        Spacer()
                        Button("システム設定を開く") { AccessibilityService.openAccessibilitySettings() }
                            .controlSize(.small)
                        Button("再確認") { accessibilityTrusted = AccessibilityService.isTrusted }
                            .controlSize(.small)
                    }
                }

                section("ログ（開発用）") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("判定ログを記録する", isOn: $settings.loggingEnabled)
                        Text(log.metricsSummary())
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        HStack {
                            Button("ログの場所を開く") {
                                NSWorkspace.shared.activateFileViewerSelecting([log.logFileURL])
                            }
                            .controlSize(.small)
                            Spacer()
                        }
                        Text("入力値そのものはログに残りません。")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// メニューバーから開くメインウィンドウ。
struct MainWindowView: View {
    @ObservedObject var store: ProfileStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var log: DebugLog

    var body: some View {
        TabView {
            ProfileFormView(store: store)
                .tabItem { Label("登録情報", systemImage: "list.bullet") }
            SettingsView(settings: settings, log: log)
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .frame(minWidth: 560, idealWidth: 600, minHeight: 560, idealHeight: 680)
    }
}
