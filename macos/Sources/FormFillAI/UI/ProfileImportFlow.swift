import AppKit
import FormFillAICore
import UniformTypeIdentifiers

/// JSON からの一括登録。ファイル選択 → 方式の確認 → 結果表示までの一連の対話。
@MainActor
enum ProfileImportFlow {

    /// 数十件を手入力するのは現実的でないため、JSON からまとめて登録する。
    static func run(store: ProfileStore) {
        let panel = NSOpenPanel()
        panel.title = "登録情報の JSON を選択"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var replaceAll = false
        if !store.items.isEmpty {
            let mode = NSAlert()
            mode.messageText = "既存の \(store.items.count) 件をどうしますか？"
            mode.informativeText = """
                「追加・更新」は同じ項目名だけ上書きします。項目は減りません。
                「すべて置き換える」は既存を消してから読み込みます。
                """
            mode.addButton(withTitle: "追加・更新")
            mode.addButton(withTitle: "すべて置き換える")
            mode.addButton(withTitle: "キャンセル")
            switch mode.runModal() {
            case .alertSecondButtonReturn: replaceAll = true
            case .alertThirdButtonReturn: return
            default: replaceAll = false
            }
        }

        do {
            let summary = try store.importItems(from: url, replaceAll: replaceAll)
            showResult(summary, sourceURL: url)
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "読み込みに失敗しました"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private static func showResult(_ summary: ProfileStore.ImportSummary, sourceURL: URL) {
        let alert = NSAlert()
        alert.messageText = "\(summary.added) 件を追加、\(summary.updated) 件を更新しました"
            + (summary.skipped > 0 ? "（\(summary.skipped) 件スキップ）" : "")
        // 読み込んだファイルには値が平文で入っている。置きっぱなしにさせない。
        alert.informativeText = """
            読み込んだファイルには登録した値がそのまま入っています。
            不要なら削除してください。
            """
        alert.addButton(withTitle: "ファイルを削除")
        alert.addButton(withTitle: "残す")
        if alert.runModal() == .alertFirstButtonReturn {
            try? FileManager.default.trashItem(at: sourceURL, resultingItemURL: nil)
        }
    }
}
