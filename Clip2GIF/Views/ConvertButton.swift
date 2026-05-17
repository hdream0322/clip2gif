import SwiftUI

struct ConvertButton: View {
    @ObservedObject var job: ConversionJob
    let action: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if job.isRunning {
                progressBlock
            } else if case .done(let url) = job.state {
                doneBlock(url: url)
            } else if case .failed(let err) = job.state {
                Text(err.errorDescription ?? "오류가 발생했습니다.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            Button {
                Task { await action() }
            } label: {
                Label(buttonLabel, systemImage: buttonIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(job.isRunning)
            .keyboardShortcut(.return, modifiers: [])
        }
    }

    @ViewBuilder
    private var progressBlock: some View {
        ProgressView(value: job.overallProgress)
            .progressViewStyle(.linear)
            .frame(maxWidth: .infinity)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(job.stepName)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(Int(job.overallProgress * 100))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if !job.detail.isEmpty {
                Text(job.detail)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text("경과 \(formatTime(job.elapsedSeconds))")
                if let eta = job.etaSeconds {
                    Text("· 남은 시간 약 \(formatTime(eta))")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func doneBlock(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("완료", systemImage: "checkmark.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.green)
            if let size = fileSize(url: url) {
                Text("크기 \(OutputEstimator.formatted(bytes: size))")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(url.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var buttonLabel: String {
        switch job.state {
        case .done:   return "다시 변환"
        case .failed: return "재시도"
        default:      return "GIF로 변환"
        }
    }

    private var buttonIcon: String {
        switch job.state {
        case .done:   return "arrow.clockwise"
        case .failed: return "exclamationmark.arrow.circlepath"
        default:      return "wand.and.sparkles"
        }
    }

    private func formatTime(_ s: Double) -> String {
        let total = Int(s)
        let m = total / 60
        let sec = total % 60
        return m > 0 ? String(format: "%d:%02d", m, sec) : String(format: "%d초", sec)
    }

    private func fileSize(url: URL) -> Int64? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? NSNumber)?.int64Value
    }
}
