import Foundation
import AVFoundation
import CoreGraphics

/// 짧은 프리플라이트 인코딩으로 실제 GIF 용량을 예측한다.
/// gifski 앱과 비슷한 정확도(±10% 내외)를 노린 두-점 선형 회귀 방식.
enum PreflightEstimator {
    struct Result: Equatable {
        let bytes: Int64
    }

    /// 전체 프레임이 이 이하이면 회귀 없이 통째로 인코딩해 정답 반환.
    private static let directEncodeThreshold = 16
    /// 두-점 회귀용 윈도우 크기. 차이(large-small)가 프레임당 바이트의 분모.
    private static let smallWindowCount = 4
    private static let largeWindowCount = 12
    /// 윈도우 시작 위치 비율(전체 프레임 대비) — 영상 앞/뒤 치우침 완화.
    private static let smallWindowStartFraction = 0.25   // totalFrames * 1/4
    private static let largeWindowStartFraction = 0.625  // totalFrames * 5/8

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

        if totalFrames <= directEncodeThreshold {
            let size = try await encodeWindow(
                source: source,
                settings: settings,
                startFrameIndex: 0,
                count: totalFrames
            )
            return Result(bytes: size)
        }

        let smallStart = Int(Double(totalFrames) * smallWindowStartFraction)
        let largeStart = Int(Double(totalFrames) * largeWindowStartFraction)
        async let smallSize = encodeWindow(
            source: source, settings: settings,
            startFrameIndex: smallStart, count: smallWindowCount
        )
        async let largeSize = encodeWindow(
            source: source, settings: settings,
            startFrameIndex: largeStart, count: largeWindowCount
        )
        let s1 = try await smallSize
        let s2 = try await largeSize

        // 두-점 선형 회귀: 정상상태 프레임당 바이트 = ΔBytes / ΔFrames,
        // 헤더 베이스라인 = 작은 윈도우 - 작은 프레임수 * perFrame.
        let deltaFrames = Double(largeWindowCount - smallWindowCount)
        let perFrame = max(0, Double(s2 - s1) / deltaFrames)
        let baseline = max(0, Double(s1) - Double(smallWindowCount) * perFrame)
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

        let pixelCrop: CGRect? = settings.isFullFrame
            ? nil
            : settings.pixelCropRect(for: source.naturalSize)

        // 추출 로직은 FrameExtractor 의 단일 헬퍼를 인덱스만 다르게 호출.
        // (클램프·취소·톤매핑이 한 곳에 집중되어 양쪽 불일치 위험 제거)
        let indices = Array(startFrameIndex..<(startFrameIndex + count))
        let frames = try await FrameExtractor.extractFrames(
            source: source,
            settings: settings,
            outputIndices: indices,
            pixelCrop: pixelCrop,
            outputDir: tempDir,
            fileName: { offset, _ in String(format: "p_%05d", offset) }
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

}
