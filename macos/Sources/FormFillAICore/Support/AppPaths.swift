import Foundation

/// アプリのデータ保存先。MainActor に縛られないよう独立させている。
public enum AppPaths {
    public static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("FormFillAI", isDirectory: true)
    }
}
