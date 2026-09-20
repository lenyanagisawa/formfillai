import FormFillAICore
import SwiftUI

/// 入力後に必ず出す修正 UI。3〜5 秒で消えるが、ホバー中は消さない。
struct PasteFeedbackView: View {
    let label: String
    let source: FillSource
    let probability: Double?
    let onDifferent: () -> Void
    let onDismiss: () -> Void

    private static let visibleSeconds: UInt64 = 4

    @State private var isHovering = false
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        // 入力後は「違う」だけ。何が入ったかは入力欄を見れば分かる。
        Button("違う", action: onDifferent)
            .controlSize(.small)
            .help(helpText)
            .padding(6)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                dismissTask?.cancel()
            } else {
                scheduleDismiss()
            }
        }
        .onAppear { scheduleDismiss() }
        .onDisappear { dismissTask?.cancel() }
    }

    private var helpText: String {
        if let probability { return "「\(label)」を入力（確信度 \(Int((probability * 100).rounded()))%）" }
        return "「\(label)」を入力"
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(Self.visibleSeconds))
            guard !Task.isCancelled, !isHovering else { return }
            onDismiss()
        }
    }
}
