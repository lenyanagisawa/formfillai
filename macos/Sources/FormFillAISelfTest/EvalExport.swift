import Foundation
import FormFillAICore

/// 評価用の問い合わせを、アプリと同じコード（VirtualCandidateBuilder と JevPrompt）で組み立てて書き出す。
/// 評価スクリプト側に候補生成や指示文の写しを持たせないための出口。
///
///   swift run FormFillAISelfTest --dump-eval <profile.json> <cases.json>
enum EvalExport {
    private struct ProfileEntry: Decodable {
        let ref: String
        let label: String
        let semanticType: String
        let value: String
    }

    private struct Case: Decodable {
        let id: String
        /// "zip.zip_first3" のような参照名、または "__none__"。
        let expected: String
        let context: FieldContext
    }

    static func dump(profilePath: String, casesPath: String) throws {
        let decoder = JSONDecoder()
        let profile = try decoder.decode([ProfileEntry].self, from: Data(contentsOf: URL(fileURLWithPath: profilePath)))
        let cases = try decoder.decode([Case].self, from: Data(contentsOf: URL(fileURLWithPath: casesPath)))

        var idByRef: [String: String] = [:]
        var candidates: [VirtualCandidate] = []
        for (index, entry) in profile.enumerated() {
            // 実行のたびに候補 ID が変わらないよう、UUID を並び順から決める。
            let item = ProfileItem(
                id: UUID(uuidString: String(format: "%08X-0000-0000-0000-000000000000", index + 1))!,
                label: entry.label, value: entry.value,
                semanticType: SemanticType(rawValue: entry.semanticType) ?? .custom, sortOrder: index
            )
            for candidate in VirtualCandidateBuilder.build(from: item) {
                idByRef["\(entry.ref).\(candidate.variant.slug)"] = candidate.id
                candidates.append(candidate)
            }
        }

        let requests: [OrderedJSON] = try cases.map { testCase in
            let expectedId = testCase.expected == VirtualCandidate.noneId
                ? JevPrompt.noneOptionKey : idByRef[testCase.expected]
            guard let expectedId else {
                throw NSError(domain: "EvalExport", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "\(testCase.id): 候補 \(testCase.expected) は生成されません",
                ])
            }
            return .object([
                ("id", .string(testCase.id)),
                ("title", .optional(testCase.context.field.title)),
                ("expected", .string(expectedId)),
                ("body", JevPrompt.request(context: testCase.context, candidates: candidates)),
            ])
        }
        print(OrderedJSON.array(requests).serialized())
    }
}
