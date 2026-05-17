import Foundation
import AVFoundation
import CoreGraphics

/// 짧은 프리플라이트 인코딩으로 실제 GIF 용량을 예측한다.
/// gifski 앱과 비슷한 정확도(±10% 내외)를 노린 두-점 선형 회귀 방식.
enum PreflightEstimator {
    struct Result: Equatable {
        let bytes: Int64
    }

    /// 작은 윈도우 4프레임, 큰 윈도우 12프레임 동시에 인코딩 → 선형 외삽.
    /// 전체 프레임이 16 이하이면 그냥 다 인코딩한 결과를 정답으로 반환.
    static func estimate(
        source: VideoSource,
        settings: ConversionSettings
    ) async throws -> Result {
        let trim = settings.effectiveTrimEnd(duration: source.duration) - settings.trimStart
        let speed = max(0.1, settings.speed)
        let outputDuration = max(0.0001, trim / speed)
        let totalFrames = max(1, Int(outputDuration * Double(settings.fps)))

        if totalFrames <= 16 {
            let size = try await encodeWindow(
                source: source,
                settings: settings,
                startFrameIndex: 0,
                count: totalFrames
            )
            return Result(bytes: size)
        }

        let smallStart = totalFrames / 4
        let largeStart = totalFrames * 5 / 8
        async let smallSize = encodeWindow(
            source: source, settings: settings,
            startFrameIndex: smallStart, count: 4
        )
        async let largeSize = encodeWindow(
            source: source, settings: settings,
            startFrameIndex: largeStart, count: 12
        )
        let s1 = try await smallSize
        let s2 = try await largeSize

        // (S2 - S1) / 8 = 정상상태 프레임당 바이트, S1 - 4*Δ = 헤더 베이스라인.
        let perFrame = max(0, Double(s2 - s1) / 8.0)
        let baseline = max(0, Double(s1) - 4 * perFrame)
        let total = baseline + perFrame * Double(totalFrames)
        return Result(bytes: Int64(total))
    }

    private static func encodeWindow(
        source: VideoSource,
        settings: ConversionSettings,
        startFrameIndex: Int,
        count: Int
    ) async throws -> Int64 {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("preflight-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let speed = max(0.1, settings.speed)
        let pixelCrop: CGRect? = settings.isFullFrame
            ? nil
            : settings.pixelCropRect(for: source.naturalSize)

        let frames = try await extractWindow(
            source: source,
            settings: settings,
            startFrameIndex: startFrameIndex,
            count: count,
            speed: speed,
            pixelCrop: pixelCrop,
            tempDir: tempDir
        )

        let gifURL = tempDir.appendingPathComponent("preflight.gif")
        try await GifskiEncoder.encode(
            frames: frames,
            settings: settings,
            naturalSize: source.naturalSize,
            output: gifURL
        ) { _ in }

        let attrs = try FileManager.default.attributesOfItem(atPath: gifURL.path)
        return (attrs[.size] as? NSNumber)?.int64Value ?? 0
    }

    private static func extractWindow(
        source: VideoSource,
        settings: ConversionSettings,
        startFrameIndex: Int,
        count: Int,
        speed: Double,
        pixelCrop: CGRect?,
        tempDir: URL
    ) async throws -> [URL] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[URL], Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let asset = AVURLAsset(url: source.url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.requestedTimeToleranceBefore = CMTimeMake(value: 1, timescale: 600)
                generator.requestedTimeToleranceAfter = CMTimeMake(value: 1, timescale: 600)

                let trimStart = settings.trimStart
                let trimEnd = settings.effectiveTrimEnd(duration: source.duration)

                var urls: [URL] = []
                urls.reserveCapacity(count)

                for i in 0..<count {
                    let result: Swift.Result<URL, Error> = autoreleasepool {
                        let outputIndex = startFrameIndex + i
                        // FrameExtractor 와 동일하게 [start, end-epsilon] 클램프.
                        // (startFrameIndex+i 가 totalFrames 를 넘어 영상 밖 시간을
                        //  요청하면 copyCGImage 가 throw → 추정 전체 실패)
                        let raw = trimStart
                            + (Double(outputIndex) / Double(settings.fps)) * speed
                        let seconds = min(raw, max(trimStart, trimEnd - 1.0 / 600.0))
                        let time = CMTimeMakeWithSeconds(seconds, preferredTimescale: 600)
                        do {
                            let cg = try generator.copyCGImage(at: time, actualTime: nil)
                            let cropped = FrameExtractor.applyCrop(cg, crop: pixelCrop) ?? cg
                            let final = FrameExtractor.toneMappedSDR(cropped)
                            let url = tempDir.appendingPathComponent(String(format: "p_%05d.png", i))
                            try FrameExtractor.writePNG(final, to: url)
                            return .success(url)
                        } catch {
                            return .failure(ConversionError.ioFailed(error.localizedDescription))
                        }
                    }
                    switch result {
                    case .success(let url): urls.append(url)
                    case .failure(let err):
                        continuation.resume(throwing: err)
                        return
                    }
                }
                continuation.resume(returning: urls)
            }
        }
    }
}
