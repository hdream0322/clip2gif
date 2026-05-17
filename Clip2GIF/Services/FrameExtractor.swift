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
        let speed = max(0.1, settings.speed)
        let end = settings.effectiveTrimEnd(duration: source.duration)
        let sourceTrimDuration = max(0.0001, end - settings.trimStart)
        // 출력 GIF 길이 = 원본 트림 구간 / 속도 배율
        let outputDuration = sourceTrimDuration / speed
        let totalFrames = max(1, Int(outputDuration * Double(settings.fps)))

        let pixelCrop: CGRect? = settings.isFullFrame
            ? nil
            : settings.pixelCropRect(for: source.naturalSize)

        return try await extractFrames(
            source: source,
            settings: settings,
            outputIndices: Array(0..<totalFrames),
            pixelCrop: pixelCrop,
            outputDir: outputDir,
            fileName: { _, outputIndex in String(format: "frame_%05d", outputIndex) },
            onProgress: progress
        )
    }

    /// 프레임 추출의 단일 구현. FrameExtractor.extract 와
    /// PreflightEstimator.extractWindow 가 이 헬퍼를 인덱스만 다르게 호출한다.
    /// (예전엔 두 곳에 루프가 복제돼 클램프·취소 같은 수정이 한쪽에서 누락되기 쉬웠음)
    ///
    /// - outputIndices: 추출할 "출력 프레임" 인덱스들. 시간 = trimStart + (idx/fps)*speed,
    ///   부동소수 오차로 끝을 넘지 않도록 [trimStart, trimEnd-1/600s] 로 클램프.
    /// - fileName: (배열 내 위치 offset, outputIndex) → 확장자 없는 파일명.
    /// - onProgress: 진행률(0~1). 메인 스레드로 디스패치되어 호출됨.
    static func extractFrames(
        source: VideoSource,
        settings: ConversionSettings,
        outputIndices: [Int],
        pixelCrop: CGRect?,
        outputDir: URL,
        fileName: @escaping (_ offset: Int, _ outputIndex: Int) -> String,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> [URL] {
        let trimStart = settings.trimStart
        let trimEnd = settings.effectiveTrimEnd(duration: source.duration)
        let speed = max(0.1, settings.speed)
        let fps = Double(settings.fps)
        let total = outputIndices.count

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
                    urls.reserveCapacity(total)

                    for (offset, outputIndex) in outputIndices.enumerated() {
                        if token.isCancelled {
                            continuation.resume(throwing: ConversionError.cancelled)
                            return
                        }
                        // 프레임마다 autoreleasepool로 즉시 해제
                        let result: Result<URL, Error> = autoreleasepool {
                            let raw = trimStart + (Double(outputIndex) / fps) * speed
                            let seconds = min(raw, max(trimStart, trimEnd - 1.0 / 600.0))
                            let time = CMTimeMakeWithSeconds(seconds, preferredTimescale: 600)
                            do {
                                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                                let cropped = applyCrop(cgImage, crop: pixelCrop) ?? cgImage
                                let finalImage = toneMappedSDR(cropped)
                                let frameURL = outputDir.appendingPathComponent(
                                    fileName(offset, outputIndex) + ".png"
                                )
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

                        if let onProgress {
                            let p = Double(offset + 1) / Double(total)
                            DispatchQueue.main.async { onProgress(p) }
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
