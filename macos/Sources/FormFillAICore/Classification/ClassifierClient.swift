import Foundation

/// Jev に 1 回の Choice を依頼する。経路（JevConnection）は設定で選べる。
///
/// 接続（TCP + TLS）は使い回す。判定のたびに張り直すと、それだけで 0.1 秒前後かかる。
public final class ClassifierClient: @unchecked Sendable {

    public enum ClassifierError: LocalizedError {
        case notConfigured(JevConnection)
        case unauthorized
        case billingRequired(String?)
        case freeTierBlocked
        case dailyQuotaExhausted
        case rateLimited
        case badStatus(Int, String?)
        case timedOut
        case transport(String)
        case decoding(String)

        public var errorDescription: String? {
            switch self {
            case .notConfigured(let connection):
                return "接続先（\(connection.title)）が設定されていません。設定タブで入力してください。"
            case .unauthorized:
                return "API キーまたはトークンが正しくありません。設定を確認してください。"
            case .freeTierBlocked:
                return """
                    Jev は無料枠では使えなくなりました。AI Gateway でクレジットを購入すると使えます（$1 から・1回あたり約0.02円）。
                    Vercel のダッシュボード → AI Gateway → Credits
                    """
            case .dailyQuotaExhausted:
                return """
                    今日の無料枠（1 日 10,000 ニューロン、約 125 回）を使い切りました。
                    日付が変わると回復します（UTC 0 時 = 日本時間 午前 9 時）。
                    """
            case .billingRequired(let detail):
                return detail ?? "AI Gateway の課金設定が必要です。Vercel のダッシュボードを確認してください。"
            case .rateLimited:
                return "レート制限に達しました。少し待って再試行してください。"
            case .badStatus(let code, let body):
                return "APIエラー (HTTP \(code))\(body.map { ": \($0)" } ?? "")"
            case .timedOut:
                return "AI判定がタイムアウトしました"
            case .transport(let message):
                return "通信に失敗しました: \(message)"
            case .decoding(let message):
                return "レスポンスを解釈できませんでした: \(message)"
            }
        }
    }

    private let session: URLSession
    private var lastWarmUp = Date.distantPast

    /// サーバレス関数は数分使われないと停止し、次の 1 回が遅くなる。
    private static let warmUpInterval: TimeInterval = 180

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = 2
        session = URLSession(configuration: configuration)
    }

    @MainActor
    public func classify(
        context: FieldContext,
        candidates: [VirtualCandidate],
        settings: AppSettings
    ) async throws -> ClassificationResult {
        let body = JevPrompt.request(context: context, candidates: candidates, style: settings.connection.candidateStyle)
        let timeoutMs = max(1000, Int(settings.requestTimeout * 1000) - 300)
        guard var request = settings.connection.makeRequest(
            body: body, credentials: settings.credentials, timeoutMs: timeoutMs
        ) else {
            throw ClassifierError.notConfigured(settings.connection)
        }
        request.timeoutInterval = settings.requestTimeout

        let (data, response) = try await send(request)
        try Self.validate(response, data: data)
        lastWarmUp = Date()

        do {
            return try JevPrompt.parse(data)
        } catch {
            throw ClassifierError.decoding(error.localizedDescription)
        }
    }

    /// 接続（と中継サーバーの関数）を温めておく。Jev は呼ばないので費用はかからない。
    /// GET はエラーで即座に返るが、TLS 接続は確立され、関数も起動状態になる。
    @MainActor
    public func warmUpIfNeeded(settings: AppSettings) {
        guard Date().timeIntervalSince(lastWarmUp) > Self.warmUpInterval,
              let url = settings.connection.makeRequest(
                  body: .object([]), credentials: settings.credentials, timeoutMs: 1000
              )?.url
        else { return }
        lastWarmUp = Date()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        let session = session
        Task.detached(priority: .utility) { _ = try? await session.data(for: request) }
    }

    // MARK: - 内部

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ClassifierError.timedOut
        } catch {
            throw ClassifierError.transport(error.localizedDescription)
        }
    }

    private static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ClassifierError.transport("不正なレスポンス")
        }
        guard !(200..<300).contains(http.statusCode) else { return }
        let message = errorMessage(from: data)

        // 課金まわりの問題は、経路によって 403 だったり 402 だったりする。
        // ステータスより先に本文で判断しないと「キーが違う」と誤って案内してしまう。
        if let message {
            if message.range(of: "daily free allocation|free allocation of", options: [.regularExpression, .caseInsensitive]) != nil {
                throw ClassifierError.dailyQuotaExhausted
            }
            if message.range(of: "free tier", options: .caseInsensitive) != nil {
                throw ClassifierError.freeTierBlocked
            }
            if message.range(of: "credit card|credits|billing|payment", options: [.regularExpression, .caseInsensitive]) != nil {
                throw ClassifierError.billingRequired(message)
            }
        }

        switch http.statusCode {
        case 401, 403: throw ClassifierError.unauthorized
        case 402: throw ClassifierError.billingRequired(message)
        case 429: throw ClassifierError.rateLimited
        case 504: throw ClassifierError.timedOut
        default: throw ClassifierError.badStatus(http.statusCode, message)
        }
    }

    /// `{"error": "..."}` と `{"error": {"message": "..."}}` の両方を読む。
    private static func errorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data.prefix(200), encoding: .utf8)
        }
        if let text = object["error"] as? String { return String(text.prefix(300)) }
        if let nested = object["error"] as? [String: Any], let text = nested["message"] as? String {
            return String(text.prefix(300))
        }
        // Cloudflare は errors の配列で返す。
        if let errors = object["errors"] as? [[String: Any]], let text = errors.first?["message"] as? String {
            return String(text.prefix(300))
        }
        return nil
    }
}
