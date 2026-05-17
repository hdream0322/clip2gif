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
    /// 결과 GIF 를 별도 모달 창으로 다시 띄울 때 호출.
    var onShowResult: (URL) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if job.isRunning {
                progressBlock
            } else if case .done(let url) = job.state {
                if job.isBatch {
                    batchDoneBlock(dir: url)
                } else {
                    doneBlock(url: url)
                }
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
        if job.batchTotal > 0 {
            ProgressView(
                value: Double(job.batchDone),
                total: Double(max(1, job.batchTotal))
            )
            .progressViewStyle(.linear)
            .frame(maxWidth: .infinity)
        } else {
            ProgressView(value: job.overallProgress)
                .progressViewStyle(.linear)
                .frame(maxWidth: .infinity)
        }
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(job.stepName)
                    .font(.subheadline.bold())
                Spacer()
                if job.batchTotal > 0 {
                    Text("\(job.batchDone)/\(job.batchTotal)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(Int(job.overallProgress * 100))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
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

            Button {
                onShowResult(url)
            } label: {
                Label("미리보기 창 열기", systemImage: "rectangle.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

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

    @ViewBuilder
    private func batchDoneBlock(dir: URL) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("배치 완료", systemImage: "checkmark.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.green)
            Text(verbatim: batchSummaryText)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([dir])
            } label: {
                Label("폴더 열기", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var batchSummaryText: String {
        var t = "성공 \(job.batchDone)개"
        if job.batchFailures > 0 { t += " · 실패 \(job.batchFailures)개" }
        return t
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

/// 변환 완료 시 결과 GIF 를 별도 모달 창(sheet)으로 크게 보여준다.
struct ResultPreviewSheet: View {
    let url: URL
    var onClose: () -> Void
    @State private var copied = false

    private var pixelSize: CGSize {
        guard let img = NSImage(contentsOf: url) else {
            return CGSize(width: 480, height: 360)
        }
        if let rep = img.representations.first, rep.pixelsWide > 0 {
            return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return img.size
    }

    private var fileSizeText: String? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        guard let n = attrs?[.size] as? NSNumber else { return nil }
        return OutputEstimator.formatted(bytes: n.int64Value)
    }

    /// GIF "만" 복사한다. NSImage 를 넣으면 받는 앱이 정지 jpg/tiff 로
    /// 붙여넣으므로, 파일 URL + GIF 원본 데이터만 클립보드에 올린다.
    private func copyGIF() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([url as NSURL])
        if let data = try? Data(contentsOf: url) {
            pb.setData(data, forType: NSPasteboard.PasteboardType("com.compuserve.gif"))
        }
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copied = false
        }
    }

    var body: some View {
        let ar = pixelSize.height > 0
            ? pixelSize.width / pixelSize.height
            : 4.0 / 3.0
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("변환 완료").font(.headline)
            }

            AnimatedGIFView(url: url)
                .aspectRatio(ar, contentMode: .fit)
                .frame(maxWidth: 760, maxHeight: 560)
                .background(Color.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.secondary.opacity(0.2))
                )

            VStack(spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                if let fileSizeText {
                    Text(fileSizeText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 10) {
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
                Button {
                    copyGIF()
                } label: {
                    Label(
                        copied ? "복사됨" : "복사",
                        systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc"
                    )
                    .foregroundStyle(copied ? Color.green : Color.primary)
                }
                .help("GIF 파일을 클립보드에 복사")
                Spacer()
                Button("닫기", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 420)
    }
}
