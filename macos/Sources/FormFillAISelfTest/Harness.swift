import Foundation

/// XCTest が使えない環境（Command Line Tools のみ）向けの最小テストハーネス。
final class Harness {
    private(set) var checks = 0
    private(set) var failures = 0
    let quiet: Bool

    init(quiet: Bool) { self.quiet = quiet }

    func section(_ title: String) { say("\n■ \(title)") }

    func say(_ text: String) {
        if !quiet { print(text) }
    }

    func expect<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
        checks += 1
        if actual == expected {
            say("  ok   \(label): \(actual)")
        } else {
            failures += 1
            say("  FAIL \(label): expected \"\(expected)\" but got \"\(actual)\"")
        }
    }

    func expectTrue(_ condition: Bool, _ label: String) {
        checks += 1
        if condition {
            say("  ok   \(label)")
        } else {
            failures += 1
            say("  FAIL \(label)")
        }
    }

    func summarize() -> Int32 {
        say("\n────────────────────────")
        say(failures == 0 ? "全 \(checks) 件のチェックに合格しました" : "\(failures) / \(checks) 件が失敗しました")
        return failures == 0 ? 0 : 1
    }
}
