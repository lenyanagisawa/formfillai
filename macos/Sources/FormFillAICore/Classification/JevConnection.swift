import Foundation

/// Jev へ届く経路。どれを選んでも問い合わせ内容（JevPrompt）は同じ。
public enum JevConnection: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Vercel AI Gateway に自分の API キーで直接つなぐ。サーバーを立てなくてよい。
    case gateway
    /// 提供元の TypeSafe AI に直接つなぐ。
    case typesafe
    /// 自分で立てた中継サーバー経由。API キーを端末に置きたくない場合やチームで共有する場合。
    case relay

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .gateway: return "Vercel AI Gateway（直接）"
        case .typesafe: return "TypeSafe AI（直接・未検証）"
        case .relay: return "自前の中継サーバー"
        }
    }

    public var summary: String {
        switch self {
        case .gateway: return "自分の AI Gateway API キーで直接つなぎます。サーバーの用意は不要です。"
        case .typesafe: return "提供元の API に直接つなぎます。公開情報をもとに実装していますが、実際の疎通は確認できていません。"
        case .relay: return "relay/ をデプロイしたサーバーを経由します。API キーを端末に置かずに済みます。"
        }
    }

    /// 送信先と、経路ごとに異なるヘッダ・追加フィールドを組み立てる。
    func makeRequest(body: OrderedJSON, credentials: Credentials, timeoutMs: Int) -> URLRequest? {
        var payload = body
        var headers: [String: String] = ["Content-Type": "application/json"]
        let url: URL?

        switch self {
        case .gateway:
            // @ai-sdk/gateway が内部で使っているエンドポイント。公開ドキュメントには無いため、
            // SDK の更新で変わる可能性がある。変わったらここだけ直せばよい。
            url = URL(string: "https://ai-gateway.vercel.sh/v4/ai/evaluation-model")
            headers["Authorization"] = "Bearer \(credentials.gatewayKey)"
            headers["ai-gateway-protocol-version"] = "0.0.1"
            headers["ai-gateway-auth-method"] = "api-key"
            headers["ai-evaluation-model-specification-version"] = "4"
            headers["ai-model-id"] = "typesafe-ai/jev"

        case .typesafe:
            url = URL(string: "https://api.typesafe.ai/v1/systemone")
            headers["Authorization"] = "Bearer \(credentials.typesafeKey)"
            payload = payload.adding(("model", .string("jev-latest")))

        case .relay:
            url = URL(string: credentials.relayURL.trimmingCharacters(in: .whitespacesAndNewlines))
            if !credentials.relayToken.isEmpty { headers["Authorization"] = "Bearer \(credentials.relayToken)" }
            // サーバ側が先に諦めるよう、こちらの待ち時間を伝える。
            payload = payload.adding(("timeoutMs", .number(timeoutMs)))
        }

        guard let url, url.scheme?.hasPrefix("http") == true else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload.data
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }

    func isConfigured(_ credentials: Credentials) -> Bool {
        switch self {
        case .gateway: return !credentials.gatewayKey.isEmpty
        case .typesafe: return !credentials.typesafeKey.isEmpty
        case .relay: return URL(string: credentials.relayURL)?.scheme?.hasPrefix("http") == true
        }
    }

    /// 経路ごとの接続情報。キーとトークンは Keychain に保存される。
    public struct Credentials: Sendable {
        public var gatewayKey = ""
        public var typesafeKey = ""
        public var relayURL = ""
        public var relayToken = ""
        public init() {}
    }
}

extension OrderedJSON {
    /// object の末尾にキーを足す。object 以外ならそのまま返す。
    func adding(_ pair: (key: String, value: OrderedJSON)) -> OrderedJSON {
        guard case .object(let pairs) = self else { return self }
        return .object(pairs + [pair])
    }
}

// セルフテストから経路ごとのリクエストを確認するための入口。
extension JevConnection {
    public func requestForTest(credentials: Credentials) -> URLRequest? {
        makeRequest(body: .object([("questions", .object([("field", .object([("criteria", .object([(JevPrompt.noneOptionKey, .null)]))]))]))]),
                    credentials: credentials, timeoutMs: 2000)
    }
    public func isConfiguredForTest(_ credentials: Credentials) -> Bool { isConfigured(credentials) }
}
