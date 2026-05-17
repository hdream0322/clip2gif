import Foundation
import CoreGraphics

/// GIF 출력 용량 추정. 콘텐츠 복잡도에 따라 ±3배까지 차이 나므로 범위로 표시.
enum OutputEstimator {
    /// 프레임당 픽셀당 평균 바이트(LZW + 팔레트 압축 + 프레임간 중복 가정).
    /// 복잡한 동적 콘텐츠 기준 상한값. 정적 콘텐츠는 이의 1/3 수준.
    private static func bytesPerPixel(quality: Int) -> Double {
        let q = max(1, min(100, quality))
        return 0.003 + (Double(q) / 100.0) * 0.030
    }

    struct Range {
        let low: Int64
        let high: Int64

        /// gifski 앱처럼 중앙값을 기준으로 MB 단위로 반올림한 단일 추정치.
        var formatted: String {
            let mid = Double(low + high) / 2.0
            return OutputEstimator.formattedRoundedMB(bytes: mid)
        }

        var rangeFormatted: String {
            "\(OutputEstimator.formatted(bytes: low)) ~ \(OutputEstimator.formatted(bytes: high))"
        }
    }

    static func estimateRange(
        cropPixelSize: CGSize,
        fps: Int,
        durationSeconds: Double,
        quality: Int
    ) -> Range {
        let frames = max(1.0, Double(fps) * max(0, durationSeconds))
        let pixelsPerFrame = max(0, cropPixelSize.width * cropPixelSize.height)
        let basis = pixelsPerFrame * frames * bytesPerPixel(quality: quality)
        // 정적 콘텐츠 ~30%, 복잡 콘텐츠 ~100%(상한)
        return Range(low: Int64(basis * 0.30), high: Int64(basis))
    }

    static func formatted(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// gifski 앱과 비슷하게 1MB 단위(또는 작은 파일은 KB)로 반올림.
    static func formattedRoundedMB(bytes: Double) -> String {
        let mb = bytes / (1024.0 * 1024.0)
        if mb < 1.0 {
            let kb = max(1, Int((bytes / 1024.0).rounded()))
            return "약 \(kb) KB"
        }
        if mb < 10 {
            return String(format: "약 %.1f MB", mb)
        }
        return "약 \(Int(mb.rounded())) MB"
    }
}
