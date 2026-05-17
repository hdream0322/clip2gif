import Foundation
import CryptoKit

struct GifskiEncoder {
    /// `Clip2GIF/Resources/bin/gifski` (gifski 1.34.0) 의 SHA-256.
    /// 바이너리 교체 시 `shasum -a 256 Clip2GIF/Resources/bin/gifski` 로
    /// 재계산해 이 상수를 갱신해야 한다.
    private static let expectedSHA256 =
        "42bde7c5b55ab6ee3d41c7daab1cd3c499d848eecf077409b840f56fcd64a156"

    /// CLI 인자 총 길이 상한(보수치). macOS ARG_MAX(약 1MB) 한참 아래로 잡아
    /// posix_spawn 의 E2BIG / 인자 잘림을 사전에 차단한다.
    private static let maxArgBytes = 700_000

    static func locate() throws -> URL {
        guard let url = Bundle.main.url(forResource: "gifski", withExtension: nil) else {
            throw ConversionError.binaryMissing
        }
        // 무결성 검증: 번들된 바이너리가 빌드 시점 원본과 동일한지 SHA-256 으로 확인.
        // (App Sandbox OFF·미서명 앱이라 번들 내 gifski 가 교체되면 사용자 권한
        //  임의 코드 실행으로 이어진다 → 실행 전에 차단)
        guard let data = try? Data(contentsOf: url) else {
            throw ConversionError.binaryMissing
        }
        let digest = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        guard digest == expectedSHA256 else {
            throw ConversionError.binaryTampered
        }
        // 무결성이 확인된 바이너리에 한해서만 실행권한을 보정한다
        // (Xcode 가 가끔 실행권한을 떨어뜨림). 변조본에는 권한을 주지 않는다.
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

        // ARG_MAX 회피: 프레임 경로 전량을 절대경로로 넘기면 긴 영상에서
        // 인자 길이가 ARG_MAX 를 넘어 변환이 실패한다. 모든 프레임은 동일
        // 임시 디렉터리에 있으므로, 프로세스 작업 디렉터리를 그 디렉터리로
        // 두고 짧은 파일명만 인자로 전달한다. gifski 는 기본적으로 FILES 를
        // 이름순 정렬하므로 frame_%05d.png 순서가 그대로 보존된다.
        let frameDir = frames.first?.deletingLastPathComponent()
        let frameArgs = frames.map { $0.lastPathComponent }

        let approxArgBytes = args.reduce(0) { $0 + $1.utf8.count + 1 }
            + frameArgs.reduce(0) { $0 + $1.utf8.count + 1 }
        guard approxArgBytes < maxArgBytes else {
            throw ConversionError.tooManyFrames(frames.count)
        }
        args += frameArgs

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = gifskiURL
            process.arguments = args
            if let frameDir { process.currentDirectoryURL = frameDir }

            let stderrPipe = Pipe()
            process.standardError = stderrPipe

            // stderr 누적과 진행상태 플래그(synthetic/sawRealProgress)를 단일
            // 시리얼 큐로 직렬화한다. readabilityHandler 와 terminationHandler 는
            // 서로 다른 백그라운드 스레드에서 동시 호출될 수 있어, 동기화 없이
            // Data/Bool 을 공유하면 데이터 경쟁(크래시·stderr 손실)이 된다.
            let syncQueue = DispatchQueue(label: "com.heodream.clip2gif.gifski")
            var stderrData = Data()
            var sawRealProgress = false
            var synthetic = 0.0
            let framePattern = try? NSRegularExpression(pattern: #"Frame (\d+) / (\d+)"#)

            // gifski는 파이프(비-TTY) 환경에서 진행 로그를 안 내보내는 경우가 많아
            // 인코딩 단계 막대가 멈췄다 100%로 튄다. 실제 진행값을 파싱하면 그걸
            // 쓰고, 없으면 0.9까지 점근하는 합성 진행률로 부드럽게 채운다.
            // (ticker 도 syncQueue 에서 돌려 synthetic/sawRealProgress 접근을 일원화)
            let ticker = DispatchSource.makeTimerSource(queue: syncQueue)
            ticker.schedule(deadline: .now() + 0.15, repeating: 0.15)
            ticker.setEventHandler {
                guard !sawRealProgress else { return }
                synthetic += (0.9 - synthetic) * 0.05
                let value = min(0.9, synthetic)
                DispatchQueue.main.async { progress(value) }
            }
            ticker.resume()

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else { return }
                syncQueue.async { stderrData.append(chunk) }

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
                        syncQueue.async { sawRealProgress = true }
                        DispatchQueue.main.async { progress(value) }
                    }
                }
            }

            process.terminationHandler = { proc in
                ticker.cancel()
                let handle = stderrPipe.fileHandleForReading
                handle.readabilityHandler = nil
                // termination 콜백이 마지막 readability 청크보다 먼저 올 수 있으므로
                // 잔여 stderr 를 직접 흡수해 에러 메시지 손실을 막는다.
                let remaining = (try? handle.readToEnd()) ?? Data()
                let code = proc.terminationStatus
                syncQueue.async {
                    stderrData.append(remaining)
                    if code == 0 {
                        DispatchQueue.main.async { progress(1.0) }
                        continuation.resume()
                    } else {
                        let stderrString = String(data: stderrData, encoding: .utf8) ?? ""
                        continuation.resume(
                            throwing: ConversionError.gifskiCrashed(code: code, stderr: stderrString)
                        )
                    }
                }
            }

            do {
                try process.run()
            } catch {
                ticker.cancel()
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: ConversionError.ioFailed(error.localizedDescription))
            }
        }
    }
}
