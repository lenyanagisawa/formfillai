import FormFillAICore
import SwiftUI

/// 候補選択 UI。
/// ここでは value を表示してよい。ローカル処理だけで完結しているため。
struct CandidateListView: View {
    let headline: String
    let ranked: [RankedCandidate]
    let all: [VirtualCandidate]
    let resolveValue: (VirtualCandidate) -> String?
    let onSelect: (VirtualCandidate) -> Void
    let onDismiss: () -> Void

    @State private var showingAll = false

    private static let rowHeight: CGFloat = 46

    private var listHeight: CGFloat {
        let content = CGFloat(max(visible.count, 1)) * Self.rowHeight
        return min(content, showingAll ? 320 : 220)
    }

    /// 既定では上位 3 件だけ出す。「すべて表示」で全候補に広げる。
    private var visible: [RankedCandidate] {
        showingAll ? mergedAll() : Array(mergedAll().prefix(3))
    }

    /// Jev の分布順の候補に、分布へ現れなかった候補を後ろから足す。
    private func mergedAll() -> [RankedCandidate] {
        var result = ranked
        let known = Set(ranked.map(\.id))
        result.append(contentsOf: all.filter { !known.contains($0.id) }
            .map { RankedCandidate(candidate: $0, probability: nil) })
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(headline)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            // ScrollView は固有の高さを持たないため、パネルの自動サイズ決定では
            // 高さ 0 に潰れて候補が 1 件も見えなくなる。件数から高さを決める。
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(visible) { entry in
                        CandidateRow(
                            entry: entry,
                            value: resolveValue(entry.candidate),
                            onSelect: { onSelect(entry.candidate) }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: listHeight)

            if !showingAll, visible.count < all.count {
                Button("すべて表示（\(all.count)件）") { showingAll = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 14)
            }
        }
        .padding(.bottom, 12)
    }
}

private struct CandidateRow: View {
    let entry: RankedCandidate
    let value: String?
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.candidate.label)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    if let value, !value.isEmpty {
                        Text(value)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                if let probability = entry.probability {
                    Text("\(Int((probability * 100).rounded()))%")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
