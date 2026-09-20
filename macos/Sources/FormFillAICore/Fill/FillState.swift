import Foundation

/// 確率つきの候補。確率が nil のものは Jev の分布に含まれなかった候補。
public struct RankedCandidate: Identifiable, Sendable {
    public let candidate: VirtualCandidate
    public let probability: Double?
    public var id: String { candidate.id }

    public init(candidate: VirtualCandidate, probability: Double?) {
        self.candidate = candidate
        self.probability = probability
    }
}

/// 入力された値がどこから決まったか。
public enum FillSource: String, Sendable {
    case jev
    case manual
}

/// 1 回の試行がどう終わったか（ログ用）。
public enum FillOutcome: String, Sendable {
    case autoPaste = "auto-paste"
    case manual
    case candidateUI = "candidate-ui"
    case none
    case error
}

public struct PastedInfo: Sendable {
    public let candidate: VirtualCandidate
    public let source: FillSource
    /// 選んだ候補の確率。Jev の分布に無い候補を手動で選んだときは nil。
    public let probability: Double?
    /// 「違う」で出す代替候補（自分自身は除く）。
    public let alternatives: [RankedCandidate]
}

public struct ChoosingInfo: Sendable {
    public let headline: String
    public let ranked: [RankedCandidate]
    /// すべての候補（「すべて表示」用）。
    public let all: [VirtualCandidate]
}

public struct FailureInfo: Sendable {
    public let message: String
    public let canRetry: Bool
    public let canChooseManually: Bool

    public init(message: String, canRetry: Bool, canChooseManually: Bool) {
        self.message = message
        self.canRetry = canRetry
        self.canChooseManually = canChooseManually
    }

    static let needsPermission = FailureInfo(
        message: "アクセシビリティ権限が必要です。システム設定 > プライバシーとセキュリティ > アクセシビリティ で FormFillAI を許可してください。",
        canRetry: false, canChooseManually: false
    )

    static let noProfileItems = FailureInfo(
        message: "登録情報がありません。メニューバーから情報を追加してください。",
        canRetry: false, canChooseManually: false
    )

    static let unknownCandidate = FailureInfo(
        message: "AIが未知の候補を返しました", canRetry: true, canChooseManually: true
    )

    static let valueUnavailable = FailureInfo(
        message: "値を生成できませんでした", canRetry: false, canChooseManually: true
    )

    static func focusFailed(diagnostics: String) -> FailureInfo {
        FailureInfo(message: "入力欄を取得できませんでした。\n\(diagnostics)",
                    canRetry: true, canChooseManually: false)
    }

    /// 入力欄は取れたが対象外（パスワード欄など）。
    static func unsupportedField(_ error: Error) -> FailureInfo {
        FailureInfo(message: error.localizedDescription, canRetry: true, canChooseManually: false)
    }

    /// 判定や入力の途中で失敗した。勝手に候補を選ばず、ユーザーに委ねる。
    static func recoverable(_ error: Error) -> FailureInfo {
        FailureInfo(message: error.localizedDescription, canRetry: true, canChooseManually: true)
    }
}

/// フローティング UI が描画する状態。
public enum FillState {
    case idle
    case working
    case pasted(PastedInfo)
    case choosing(ChoosingInfo)
    case failed(FailureInfo)
}
