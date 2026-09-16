import SwiftUI
import AppKit

/// 배치 변환 진행 현황 패널. 파일별 상태(대기/변환 중/완료/실패)와
/// 완료 시 출력 경로를 보여주고, 진행 중에는 취소를 제공한다.
struct BatchQueueView: View {
    @ObservedObject var queue: BatchQueue
    var onCancel: () -> Void
    var onClose: () -> Void

    private var progress: Double {
        let total = queue.items.count
        guard total > 0 else { return 0 }
        let settled = queue.items.filter {
            $0.status != .waiting && $0.status != .processing
        }.count
        return Double(settled) / Double(total)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: queue.finished ? "checkmark.circle.fill" : "square.stack.3d.up")
                    .foregroundStyle(queue.finished ? Color.green : Color.accentColor)
                Text(queue.finished ? "배치 완료" : "배치 변환 중")
                    .font(.headline)
                Spacer()
                Text("\(queue.doneCount)/\(queue.items.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(queue.items) { item in
                        row(item)
                    }
                }
            }
            .frame(minHeight: 200, maxHeight: 360)

            if queue.finished {
                HStack(spacing: 6) {
                    Text("성공 \(queue.doneCount)개")
                    if queue.failedCount > 0 {
                        Text("· 실패 \(queue.failedCount)개").foregroundStyle(.orange)
                    }
                }
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            HStack {
                if queue.isRunning {
                    Button(role: .cancel) {
                        onCancel()
                    } label: {
                        Label("취소", systemImage: "xmark.circle")
                    }
                }
                Spacer()
                Button("닫기", action: onClose)
                    .keyboardShortcut(.cancelAction)
                    .disabled(queue.isRunning)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 360)
    }

    @ViewBuilder
    private func row(_ item: BatchItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.status.systemImage)
                .foregroundStyle(color(for: item.status))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.url.lastPathComponent)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if case .failed(let msg) = item.status {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else if let out = item.outputURL {
                    Text(out.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            Text(item.status.label)
                .font(.caption.monospacedDigit())
                .foregroundStyle(color(for: item.status))
            if item.status == .done, let out = item.outputURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([out])
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("Finder에서 보기")
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(item.status == .processing ? 0.12 : 0.05))
        )
    }

    private func color(for status: BatchItemStatus) -> Color {
        switch status {
        case .waiting:    return .secondary
        case .processing: return .accentColor
        case .done:       return .green
        case .failed:     return .orange
        case .skipped:    return .secondary
        }
    }
}
