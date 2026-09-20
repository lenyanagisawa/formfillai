import FormFillAICore
import SwiftUI

/// ショートカット押下後に出る小さなフローティング UI 全体。
struct FillOverlayView: View {
    @ObservedObject var coordinator: FillCoordinator
    let resolveValue: (VirtualCandidate) -> String?

    private var isCompact: Bool {
        switch coordinator.state {
        case .working, .pasted: return true
        default: return false
        }
    }

    var body: some View {
        Group {
            switch coordinator.state {
            case .idle:
                EmptyView()

            case .working:
                WorkingView()

            case .pasted(let info):
                PasteFeedbackView(
                    label: info.candidate.label,
                    source: info.source,
                    probability: info.probability,
                    onDifferent: { coordinator.requestAlternatives() },
                    onDismiss: { coordinator.dismiss() }
                )

            case .choosing(let info):
                CandidateListView(
                    headline: info.headline,
                    ranked: info.ranked,
                    all: info.all,
                    resolveValue: resolveValue,
                    onSelect: { coordinator.choose($0) },
                    onDismiss: { coordinator.dismiss() }
                )

            case .failed(let info):
                FailureView(
                    info: info,
                    onRetry: { coordinator.trigger() },
                    onChooseManually: { coordinator.showAllCandidates() },
                    onDismiss: { coordinator.dismiss() }
                )
            }
        }
        // 判定中と入力後は邪魔にならない最小サイズ。候補選択とエラーだけ幅を取る。
        .frame(width: isCompact ? nil : 340)
        .fixedSize(horizontal: isCompact, vertical: true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: isCompact ? 9 : 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isCompact ? 9 : 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}

struct WorkingView: View {
    var body: some View {
        ProgressView()
            .controlSize(.small)
            .padding(8)
    }
}

struct FailureView: View {
    let info: FailureInfo
    let onRetry: () -> Void
    let onChooseManually: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(info.message)
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if info.canRetry {
                    Button("再試行", action: onRetry)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                if info.canChooseManually {
                    Button("すべての情報から選ぶ", action: onChooseManually)
                        .controlSize(.small)
                }
                Spacer()
                Button("閉じる", action: onDismiss)
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }
}
