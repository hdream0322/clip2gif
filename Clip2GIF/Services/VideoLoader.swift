import AVFoundation

enum VideoLoader {
    static func load(url: URL) async throws -> VideoSource {
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
