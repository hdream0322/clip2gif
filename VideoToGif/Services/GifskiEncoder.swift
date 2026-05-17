import Foundation

struct GifskiEncoder {
    static func locate() throws -> URL {
        guard let url = Bundle.main.url(forResource: "gifski", withExtension: nil) else {
            throw ConversionError.binaryMissing
        }
        // 실행 권한 확인 + 없으면 부여 시도 (Xcode가 가끔 실행권한을 떨어뜨림)
        let path = url.path
        if !FileManager.default.isExecutableFile(atPath: path) {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: path
            )
        }
        guard FileManager.default.isExecutableFile(atPath: path) else {
            throw ConversionError.binaryMissing
        }
        return url
    }

    static func encode(
        frames: [URL],
        settings: ConversionSettings,
        naturalSize: CGSize,
        output: URL,
        progress: @escaping (Double) -> Void
    ) async throws {
        let gifskiURL = try locate()

        var args: [String] = [
            "--fps", "\(settings.fps)",
            "--quality", "\(settings.quality)"
        ]

        // 크기 축소 (100% 면 생략).
        if settings.scalePercent < 100 {
            let outSize = settings.pixelOutputSize(for: naturalSize)
            args += ["--width", "\(Int(outSize.width))"]
        }

        // 반복: gifski 는 --repeat=0 무한, -1 한 번 재생.
        args += ["--repeat", settings.loopForever ? "0" : "-1"]

        // bounce: gifski 네이티브 플래그 사용. (직접 프레임을 역순으로 붙이면
        // gifski가 파일명을 다시 정렬해버려 역재생이 안 되고 프레임만 중복 →
        // 같은 fps에서 ~2배 프레임 = 절반 속도로 보이는 버그가 됨)
        if settings.bounce {
            args += ["--bounce"]
        }

        args += ["-o", output.path]
        args += frames.map { $0.path }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = gifskiURL
            process.arguments = args

            let stderrPipe = Pipe()
            process.standardError = stderrPipe

            var stderrData = Data()
            let framePattern = try? NSRegularExpression(pattern: #"Frame (\d+) / (\d+)"#)

            // gifski는 파이프(비-TTY) 환경에서 진행 로그를 안 내보내는 경우가 많아
            // 인코딩 단계 막대가 멈췄다 100%로 튄다. 실제 진행값을 파싱하면 그걸
            // 쓰고, 없으면 0.9까지 점근하는 합성 진행률로 부드럽게 채운다.
            var sawRealProgress = false
            var synthetic = 0.0
            let ticker = DispatchSource.makeTimerSource(queue: .main)
            ticker.schedule(deadline: .now() + 0.15, repeating: 0.15)
            ticker.setEventHandler {
                guard !sawRealProgress else { return }
                synthetic += (0.9 - synthetic) * 0.05
                progress(min(0.9, synthetic))
            }
            ticker.resume()

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else { return }
                stderrData.append(chunk)

                if let text = String(data: chunk, encoding: .utf8) {
                    let range = NSRange(text.startIndex..., in: text)
                    framePattern?.enumerateMatches(in: text, range: range) { match, _, _ in
                        guard let match = match,
                              let currentRange = Range(match.range(at: 1), in: text),
                              let totalRange = Range(match.range(at: 2), in: text),
                              let current = Double(text[currentRange]),
                              let total = Double(text[totalRange]),
                              total > 0 else { return }
                        let value = current / total
                        DispatchQueue.main.async {
                            sawRealProgress = true
                            progress(value)
                        }
                    }
                }
            }

            process.terminationHandler = { proc in
                ticker.cancel()
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                let code = proc.terminationStatus
                if code == 0 {
                    DispatchQueue.main.async { progress(1.0) }
                    continuation.resume()
                } else {
                    let stderrString = String(data: stderrData, encoding: .utf8) ?? ""
                    continuation.resume(throwing: ConversionError.gifskiCrashed(code: code, stderr: stderrString))
                }
            }

            do {
                try process.run()
            } catch {
                ticker.cancel()
                continuation.resume(throwing: ConversionError.ioFailed(error.localizedDescription))
            }
        }
    }
}
