import Foundation
import FormFillAICore

// Xcode 非依存で回せる検証用の実行ファイル。
//
//   swift run FormFillAISelfTest                  全チェックを実行
//   swift run FormFillAISelfTest --dump-request   Jev へ送る JSON だけを出力
//   swift run FormFillAISelfTest --dump-eval <profile.json> <cases.json>
//                                              評価用の問い合わせを、アプリと同じコードで組み立てて出力

if let index = CommandLine.arguments.firstIndex(of: "--dump-eval"),
   CommandLine.arguments.indices.contains(index + 2) {
    try EvalExport.dump(profilePath: CommandLine.arguments[index + 1], casesPath: CommandLine.arguments[index + 2])
    exit(0)
}

let dumpRequestOnly = CommandLine.arguments.contains("--dump-request")
let harness = Harness(quiet: dumpRequestOnly)

runTransformTests(harness)
runCandidateTests(harness)
runProtocolTests(harness)

if dumpRequestOnly {
    print(Fixtures.requestJSON)
}

exit(harness.summarize())
