import AppKit
import FormFillAICore

/// メニューバー常駐アプリ。Dock にはアイコンを出さない。
///
/// 画面を使わずに初期設定するための引数:
///
///   FormFillAI --import <file.json>            登録情報を取り込む（追加・更新のみ）
///   FormFillAI --connect gateway <api-key>     AI Gateway に直接つなぐ
///   FormFillAI --connect typesafe <api-key>    TypeSafe AI に直接つなぐ
///   FormFillAI --connect relay <url> <token>   自前の中継サーバー経由でつなぐ
///
/// 値やキーは Keychain に入るため、署名されたこのバイナリ経由で行う必要がある。
@main
enum FormFillAIMain {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if let command = arguments.first, command.hasPrefix("--") {
            exit(MainActor.assumeIsolated { runCommand(command, Array(arguments.dropFirst())) })
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        // ARC で解放されないよう保持する。
        objc_setAssociatedObject(app, "FormFillAIDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        app.run()
    }

    @MainActor
    private static func runCommand(_ command: String, _ arguments: [String]) -> Int32 {
        switch (command, arguments.count) {
        case ("--import", 1):
            let store = ProfileStore()
            do {
                let summary = try store.importItems(from: URL(fileURLWithPath: arguments[0]))
                if let error = store.lastError { print("保存に失敗: \(error)"); return 1 }
                print("追加 \(summary.added) / 更新 \(summary.updated) / スキップ \(summary.skipped)（合計 \(store.items.count) 件）")
                return 0
            } catch {
                print(error.localizedDescription)
                return 1
            }

        case ("--connect", 2...3):
            guard let connection = JevConnection(rawValue: arguments[0]) else { break }
            let settings = AppSettings()
            var credentials = settings.credentials
            switch (connection, arguments.count) {
            case (.gateway, 2): credentials.gatewayKey = arguments[1]
            case (.typesafe, 2): credentials.typesafeKey = arguments[1]
            case (.relay, 3): (credentials.relayURL, credentials.relayToken) = (arguments[1], arguments[2])
            default: print("引数の数が合いません"); return 1
            }
            settings.credentials = credentials
            settings.connection = connection
            print("接続先を「\(connection.title)」に設定しました")
            return 0

        default:
            break
        }
        print("使い方: --import <file.json> | --connect gateway <key> | --connect typesafe <key> | --connect relay <url> <token>")
        return 1
    }
}
