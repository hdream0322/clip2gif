import SwiftUI
import AppKit

/// 변환 결과 GIF 를 실제로 애니메이션 재생하는 뷰 (SwiftUI 는 GIF 네이티브
/// 애니메이션 미지원 → NSImageView.animates 사용).
private struct AnimatedGIFView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSImageView {
        let v = NSImageView()
        v.imageScaling = .scaleProportionallyUpOrDown
        v.animates = true
        v.image = NSImage(contentsOf: url)
        return v
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = NSImage(contentsOf: url)
        nsView.animates = true
    }
}

struct ConvertButton: View {
    @ObservedObject var job: ConversionJob
    let start: () -> Void
    let cancel: () -> Void

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

            if job.isRunning {
                Button(role: .cancel) {
                    cancel()
                } label: {
                    Label("취소", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(".", modifiers: .command)
            } else {
                Button {
                    start()
                } label: {
                    Label(buttonLabel, systemImage: buttonIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [])
            }
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
        VStack(alignment: .leading, spacing: 6) {
            Label("완료", systemImage: "checkmark.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.green)

            AnimatedGIFView(url: url)
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.2))
                )

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

            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Label("Finder에서 보기", systemImage: "folder")
                }
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("열기", systemImage: "play.rectangle")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
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
