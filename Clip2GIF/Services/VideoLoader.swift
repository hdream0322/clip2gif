import AVFoundation
import UniformTypeIdentifiers

enum VideoLoader {
    static func load(url: URL) async throws -> VideoSource {
        // 확장자 화이트리스트만으로는 위장 파일을 거를 수 없다. 실제 파일
        // 여부·가독성을 먼저 확인하고, OS 가 인식한 콘텐츠 타입이 명백히
        // 비-AV(이미지/텍스트/압축파일)면 AVFoundation 에 넘기기 전에 차단.
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir),
              !isDir.boolValue,
              fm.isReadableFile(atPath: url.path) else {
            throw ConversionError.ioFailed("파일을 읽을 수 없습니다.")
        }
        if let ct = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
           ct.conforms(to: .image) || ct.conforms(to: .text) || ct.conforms(to: .archive) {
            throw ConversionError.unsupportedCodec
        }

        let asset = AVURLAsset(url: url)

        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch let error as AVError {
            throw ConversionError.ioFailed("loadFailed: \(error.localizedDescription)")
        }

        let tracks: [AVAssetTrack]
        do {
            tracks = try await asset.load(.tracks)
        } catch let error as AVError {
            throw ConversionError.ioFailed("loadFailed: \(error.localizedDescription)")
        }

        guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
            throw ConversionError.unsupportedCodec
        }

        let naturalSize: CGSize
        do {
            let size = try await videoTrack.load(.naturalSize)
            let transform = try await videoTrack.load(.preferredTransform)
            let transformed = size.applying(transform)
            naturalSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
        } catch {
            throw ConversionError.unsupportedCodec
        }

        let frameRate: Double
        do {
            let nominal = try await videoTrack.load(.nominalFrameRate)
            frameRate = nominal > 0 ? Double(nominal) : 30
        } catch {
            frameRate = 30
        }

        let durationSeconds = CMTimeGetSeconds(duration)

        return VideoSource(url: url, duration: durationSeconds, naturalSize: naturalSize, frameRate: frameRate)
    }
}
