import Foundation

/// アプリ設定。API トークンだけは Keychain に置き、他は UserDefaults に保存する。
@MainActor
public final class AppSettings: ObservableObject {

    /// 自動入力の初期閾値。
    ///
    /// 仕様の初期値 0.90 は候補 16 個で測ったもの。候補が 50 を超えると
    /// 正解でも確率が 0.80 前後に分散するため、実測に合わせて下げている。
    public static let defaultAutoPasteThreshold = 0.75

    /// Backend のタイムアウト。
    public static let defaultTimeout: TimeInterval = 3.0

    private enum Key {
        static let relayURL = "endpointURL"
        static let connection = "connection"
        static let threshold = "autoPasteThreshold"
        static let timeout = "requestTimeout"
        static let logging = "loggingEnabled"
        static let alwaysAutoPaste = "alwaysAutoPaste"
    }

    private let defaults: UserDefaults
    private let secrets: KeychainStore

    /// Jev へ届く経路。
    @Published public var connection: JevConnection {
        didSet { defaults.set(connection.rawValue, forKey: Key.connection) }
    }

    /// 経路ごとの接続情報。URL は UserDefaults、キーとトークンは Keychain に保存する。
    @Published public var credentials: JevConnection.Credentials {
        didSet {
            defaults.set(credentials.relayURL, forKey: Key.relayURL)
            try? secrets.saveAll([
                "gatewayKey": credentials.gatewayKey,
                "typesafeKey": credentials.typesafeKey,
                "token": credentials.relayToken,
            ])
        }
    }

    @Published public var autoPasteThreshold: Double {
        didSet { defaults.set(autoPasteThreshold, forKey: Key.threshold) }
    }

    @Published public var requestTimeout: Double {
        didSet { defaults.set(requestTimeout, forKey: Key.timeout) }
    }

    @Published public var loggingEnabled: Bool {
        didSet { defaults.set(loggingEnabled, forKey: Key.logging) }
    }

    /// 確率に関わらず、まず入力してしまうモード。
    ///
    /// 「どの情報を入力しますか？」と先に聞かれるより、
    /// 一旦入って違ったら直すほうが速い、という判断。
    /// 誤入力は「違う」で直せて、その入力欄は次回から記憶される。
    @Published public var alwaysAutoPaste: Bool {
        didSet { defaults.set(alwaysAutoPaste, forKey: Key.alwaysAutoPaste) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.secrets = KeychainStore(service: "io.github.lenyanagisawa.FormFillAI", account: "api-token")

        let stored = (try? secrets.loadAll()) ?? [:]
        var credentials = JevConnection.Credentials()
        credentials.relayURL = defaults.string(forKey: Key.relayURL) ?? ""
        credentials.relayToken = stored["token"] ?? ""
        credentials.gatewayKey = stored["gatewayKey"] ?? ""
        credentials.typesafeKey = stored["typesafeKey"] ?? ""
        self.credentials = credentials
        self.connection = defaults.string(forKey: Key.connection).flatMap(JevConnection.init) ?? .gateway
        let storedThreshold = defaults.double(forKey: Key.threshold)
        self.autoPasteThreshold = storedThreshold > 0 ? storedThreshold : Self.defaultAutoPasteThreshold
        let storedTimeout = defaults.double(forKey: Key.timeout)
        self.requestTimeout = storedTimeout > 0 ? storedTimeout : Self.defaultTimeout
        // 値は残らないが、公開アプリとして控えめに、既定では記録しない。
        self.loggingEnabled = defaults.object(forKey: Key.logging) as? Bool ?? false
        self.alwaysAutoPaste = defaults.object(forKey: Key.alwaysAutoPaste) as? Bool ?? true
    }

    public var isConfigured: Bool { connection.isConfigured(credentials) }
}
