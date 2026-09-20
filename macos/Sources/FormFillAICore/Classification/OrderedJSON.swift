import Foundation

/// キーの順序を保ったまま JSON を書き出すための最小限の表現。
///
/// Jev に渡す選択肢は「よく使うものが前」という並びに意味がある。
/// Dictionary や JSONEncoder を通すと順序が失われるので、自前で直列化する。
public indirect enum OrderedJSON: Sendable {
    case string(String)
    case number(Int)
    case null
    case array([OrderedJSON])
    case object([(key: String, value: OrderedJSON)])

    public static func optional(_ value: String?) -> OrderedJSON { value.map(OrderedJSON.string) ?? .null }

    public func serialized() -> String {
        switch self {
        case .string(let value): return Self.quote(value)
        case .number(let value): return String(value)
        case .null: return "null"
        case .array(let items): return "[" + items.map { $0.serialized() }.joined(separator: ",") + "]"
        case .object(let pairs):
            return "{" + pairs.map { "\(Self.quote($0.key)):\($0.value.serialized())" }.joined(separator: ",") + "}"
        }
    }

    public var data: Data { Data(serialized().utf8) }

    /// 文字列のエスケープは Foundation に任せる。
    private static func quote(_ value: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: [value], options: [.withoutEscapingSlashes])) ?? Data("[\"\"]".utf8)
        return String(String(decoding: data, as: UTF8.self).dropFirst().dropLast())
    }
}
