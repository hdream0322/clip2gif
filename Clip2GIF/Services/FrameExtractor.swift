import AVFoundation
import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

struct FrameExtractor {
    /// HDR(HLG/PQ) → SDR sRGB 톤매핑용 컨텍스트.
    private static let toneMapContext: CIContext = {
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        return CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
            .outputColorSpace: sRGB
        ])
    }()

    static func extract(
        from source: VideoSource,
        settings: ConversionSettings,
        outputDir: URL,
        progress: @escaping (Double) -> Void
    ) async throws -> [URL] {
        let start = settings.trimStart
        let end = settings.effectiveTrimEnd(duration: source.duration)
        let sourceTrimDuration = max(0.0001, end - start)
        let speed = max(0.1, settings.speed)
        // 출력 GIF 길이 = 원본 트림 구간 / 속도 배율
        let outputDuration = sourceTrimDuration / speed
        let totalFrames = max(1, Int(outputDuration * Double(settings.fps)))

        let pixelCrop: CGRect? = settings.isFullFrame
            ? nil
            : settings.pixelCropRect(for: source.naturalSize)

        // 백그라운드 큐에서 직렬로 동기 추출 (메모리 폭주 방지).
        // Task 취소 시 토큰으로 루프를 중단해 .cancelled 로 빠져나간다.
        let token = CancellationToken()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[URL], Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                if token.isCancelled {
                    continuation.resume(throwing: ConversionError.cancelled)
                    return
                }
                let asset = AVURLAsset(url: source.url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.requestedTimeToleranceBefore = CMTimeMake(value: 1, timescale: 600)
                generator.requestedTimeToleranceAfter = CMTimeMake(value: 1, timescale: 600)

                var urls: [URL] = []
                urls.reserveCapacity(totalFrames)

                for i in 0..<totalFrames {
                    if token.isCancelled {
                        continuation.resume(throwing: ConversionError.cancelled)
                        return
                    }
                    // 프레임마다 autoreleasepool로 즉시 해제
                    let result: Result<URL, Error> = autoreleasepool {
                        // 출력 i번째 프레임 = 원본 시간 start + (i/fps)*speed.
                        // 부동소수 오차로 마지막 프레임이 end 를 미세하게 넘으면
                        // AVAssetImageGenerator 가 throw 해 전체 변환이 실패하므로
                        // [start, end-epsilon] 으로 클램프한다.
                        let raw = start + (Double(i) / Double(settings.fps)) * speed
                        let seconds = min(raw, max(start, end - 1.0 / 600.0))
                        let time = CMTimeMakeWithSeconds(seconds, preferredTimescale: 600)

                        do {
                            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                            let cropped = applyCrop(cgImage, crop: pixelCrop) ?? cgImage
                            let finalImage = toneMappedSDR(cropped)
                            let frameURL = outputDir.appendingPathComponent(String(format: "frame_%05d.png", i))
                            try writePNG(finalImage, to: frameURL)
                            return .success(frameURL)
                        } catch {
                            return .failure(ConversionError.ioFailed(error.localizedDescription))
                        }
                    }

                    switch result {
                    case .success(let url):
                        urls.append(url)
                    case .failure(let err):
                        continuation.resume(throwing: err)
                        return
                    }

                    let progressValue = Double(i + 1) / Double(totalFrames)
                    DispatchQueue.main.async {
                        progress(progressValue)
                    }
                }

                continuation.resume(returning: urls)
            }
            }
        } onCancel: {
            token.cancel()
        }
    }

    /// 메모리 효율적인 PNG 저장 (NSBitmapImageRep의 픽셀 카피 회피).
    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ConversionError.ioFailed("PNG destination 생성 실패")
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw ConversionError.ioFailed("PNG 저장 실패")
        }
    }

    /// HDR(BT.2020 HLG/PQ) 영상의 색감이 GIF로 갈 때 물빠지는 현상을 막기 위해
    /// sRGB로 톤매핑(macOS 14+) 또는 색공간 변환(macOS 13).
    static func toneMappedSDR(_ image: CGImage) -> CGImage {
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        // 이미 sRGB이면 변환 비용 절약.
        if let cs = image.colorSpace, cs.name == sRGB.name {
            return image
        }
        if #available(macOS 14.0, *) {
            let ci = CIImage(cgImage: image, options: [.toneMapHDRtoSDR: true])
            if let out = toneMapContext.createCGImage(ci, from: ci.extent, format: .RGBA8, colorSpace: sRGB) {
                return out
            }
        }
        let ci = CIImage(cgImage: image)
        return toneMapContext.createCGImage(ci, from: ci.extent, format: .RGBA8, colorSpace: sRGB) ?? image
    }

    static func applyCrop(_ image: CGImage, crop: CGRect?) -> CGImage? {
        guard let crop = crop else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let intersected = bounds.intersection(crop)
        guard !intersected.isNull, intersected.width >= 2, intersected.height >= 2 else {
            return nil
        }
        return image.cropping(to: intersected)
    }
}
