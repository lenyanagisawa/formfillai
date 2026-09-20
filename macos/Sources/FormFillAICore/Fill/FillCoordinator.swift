import AppKit
import ApplicationServices
import Foundation

/// ショートカット押下から入力完了までの一連の流れ（ の中核）。
///
///   Profile Item → Virtual Candidate → Jev Choice → Local Transform → Paste
@MainActor
public final class FillCoordinator: ObservableObject {

    /// 1 回のショートカット押下で確定した情報。「違う」での入れ直しにも使う。
    /// signature はログ上で同じ入力欄の記録を結びつけるためだけに使う。
    private struct Session {
        let target: PasteService.Target
        let signature: String
        let candidates: [VirtualCandidate]
        var result: ClassificationResult?
    }

    @Published public private(set) var state: FillState = .idle

    private let profileStore: ProfileStore
    private let settings: AppSettings
    private let pasteService: PasteService
    private let classifier: ClassifierClient
    private let log: DebugLog

    private var session: Session?
    private var isRunning = false

    public init(
        profileStore: ProfileStore,
        settings: AppSettings,
        classifier: ClassifierClient,
        pasteService: PasteService? = nil,
        log: DebugLog
    ) {
        self.profileStore = profileStore
        self.settings = settings
        self.classifier = classifier
        self.pasteService = pasteService ?? PasteService()
        self.log = log
    }

    /// UI を出す位置の基準になる、入力欄の画面上の矩形（AX 座標系）。
    public var targetFieldFrame: CGRect? {
        guard let session else { return nil }
        return AccessibilityService.frame(of: session.target.element)
    }

    // MARK: - ユーザー操作

    /// Option + Space、および失敗時の「再試行」。
    public func trigger() {
        guard !isRunning else { return }
        isRunning = true
        Task {
            await run()
            isRunning = false
        }
    }

    public func dismiss() {
        state = .idle
    }

    /// 「違う」を押したとき。
    public func requestAlternatives() {
        guard case .pasted(let info) = state, let session else { return }
        state = .choosing(ChoosingInfo(
            headline: "別の候補を選択", ranked: info.alternatives, all: session.candidates
        ))
    }

    /// 失敗時・NONE 時の「すべての情報から選ぶ」。
    public func showAllCandidates() {
        guard let session else { return }
        state = .choosing(ChoosingInfo(
            headline: "すべての情報から選ぶ",
            ranked: CandidateRanker.rank(session.candidates, by: nil),
            all: session.candidates
        ))
    }

    /// 候補を手動で選んだとき。選び直した値で入力し直す。
    public func choose(_ candidate: VirtualCandidate) {
        guard let session else { return }
        // 直前の自動入力を「修正された」として記録する（ の精度計測用）。
        log.markCorrected(signature: session.signature, finalCandidateId: candidate.id)
        Task {
            await paste(candidate, source: .manual, session: session, timer: PhaseTimer(), corrected: true)
        }
    }

    // MARK: - メインフロー

    private func run() async {
        var timer = PhaseTimer()

        guard AccessibilityService.isTrusted else {
            AccessibilityService.requestPermission()
            state = .failed(.needsPermission)
            return
        }

        // UI を出す前にフォーカス先を確定させる。
        guard let element = await FocusResolver.resolve(onWaiting: { state = .working }) else {
            let diagnostics = AccessibilityService.focusDiagnostics()
            log.appendDiagnostic("focus-failed: \(diagnostics)", enabled: settings.loggingEnabled)
            state = .failed(.focusFailed(diagnostics: diagnostics))
            return
        }
        timer.mark("focus")

        let context: FieldContext
        do {
            context = try FieldContextExtractor.extract(from: element)
        } catch {
            log.appendDiagnostic(
                "extract-failed: \(error.localizedDescription) / \(AccessibilityService.focusDiagnostics())",
                enabled: settings.loggingEnabled
            )
            state = .failed(.unsupportedField(error))
            return
        }

        let candidates = profileStore.virtualCandidates()
        guard !candidates.isEmpty else {
            state = .failed(.noProfileItems)
            return
        }

        var session = Session(
            target: PasteService.Target(element: element, app: NSWorkspace.shared.frontmostApplication),
            signature: FieldSignature.make(from: context),
            candidates: candidates,
            result: nil
        )
        self.session = session
        timer.mark("context")

        // 入力欄に手がかりが何も無いなら、Jev に投げても判断材料がない。
        //    常に自動入力モードのときは、アプリ名やページ名だけでも判断させる。
        guard context.hasAnyFieldHint || settings.alwaysAutoPaste else {
            record(.candidateUI, source: .manual, session: session, timer: timer)
            state = .choosing(ChoosingInfo(
                headline: "入力欄の手がかりがありません。どれを入力しますか？",
                ranked: CandidateRanker.rank(candidates, by: nil),
                all: candidates
            ))
            return
        }

        // Jev による 1 回の Choice。
        state = .working
        do {
            let result = try await classifier.classify(context: context, candidates: candidates, settings: settings)
            timer.mark("classify")
            session.result = result
            self.session = session
            await decide(session: session, result: result, timer: timer)
        } catch {
            // 失敗時に勝手に候補を選ばない。
            timer.mark("classify")
            record(.error, source: .jev, session: session, timer: timer)
            state = .failed(.recoverable(error))
        }
    }

    /// Jev の回答を受けて、入れるか・聞くかを決める。
    private func decide(session: Session, result: ClassificationResult, timer: PhaseTimer) async {
        // 常に自動入力モード: NONE が選ばれても、最も確率の高い実候補を入れてしまう。
        // 違えば「違う」で直せばよい。
        if settings.alwaysAutoPaste,
           let best = CandidateRanker.bestConcrete(in: result, from: session.candidates) {
            await paste(best, source: .jev, session: session, timer: timer)
            return
        }

        // NONE が選ばれた場合。
        guard !result.selectedIsNone else {
            record(.none, source: .jev, session: session, timer: timer)
            state = .choosing(ChoosingInfo(
                headline: "該当する登録情報が見つかりません", ranked: [], all: session.candidates
            ))
            return
        }

        guard let selected = session.candidates.first(where: { $0.id == result.selectedCandidateId }) else {
            record(.error, source: .jev, session: session, timer: timer)
            state = .failed(.unknownCandidate)
            return
        }

        // 閾値以上なら自動入力、未満なら候補を出す。
        if result.selectedProbability >= settings.autoPasteThreshold {
            await paste(selected, source: .jev, session: session, timer: timer)
        } else {
            record(.candidateUI, source: .jev, session: session, timer: timer)
            state = .choosing(ChoosingInfo(
                headline: "どの情報を入力しますか？",
                ranked: CandidateRanker.rank(session.candidates, by: result),
                all: session.candidates
            ))
        }
    }

    // MARK: - 入力実行

    private func paste(
        _ candidate: VirtualCandidate,
        source: FillSource,
        session: Session,
        timer: PhaseTimer,
        corrected: Bool = false
    ) async {
        var timer = timer
        guard let value = profileStore.resolveValue(for: candidate) else {
            state = .failed(.valueUnavailable)
            return
        }

        do {
            try await pasteService.paste(value, into: session.target)
            timer.mark("paste")

            // 入力後は必ず修正 UI を出す。
            state = .pasted(PastedInfo(
                candidate: candidate,
                source: source,
                probability: session.result?.probability(of: candidate.id),
                alternatives: CandidateRanker.rank(session.candidates, by: session.result, excluding: candidate)
            ))

            record(source == .jev ? .autoPaste : .manual, source: source, session: session, timer: timer,
                   corrected: corrected, finalCandidateId: candidate.id)
        } catch {
            state = .failed(.recoverable(error))
        }
    }

    // MARK: - ログ

    private func record(
        _ outcome: FillOutcome,
        source: FillSource,
        session: Session,
        timer: PhaseTimer,
        corrected: Bool = false,
        finalCandidateId: String? = nil
    ) {
        let result = session.result
        log.append(
            FillLogEntry(
                fieldSignature: session.signature,
                source: source.rawValue,
                selectedCandidateId: result?.selectedCandidateId,
                selectedProbability: result?.selectedProbability,
                choiceConfidence: result?.choiceConfidence,
                topAlternatives: (result?.sortedAlternatives.prefix(3) ?? [])
                    .map { "\($0.candidateId)=\(String(format: "%.2f", $0.probability))" },
                latencyMs: timer.totalMs,
                phases: timer.phases,
                corrected: corrected,
                finalCandidateId: finalCandidateId,
                outcome: outcome.rawValue
            ),
            enabled: settings.loggingEnabled
        )
    }
}
