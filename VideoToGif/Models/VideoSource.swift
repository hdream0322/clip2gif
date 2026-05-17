import Foundation
import AppKit

struct VideoSource: Identifiable, Equatable {
    var id: URL { url }
    let url: URL
    let duration: TimeInterval
    let naturalSize: CGSize
    /// 원본 영상의 초당 프레임 수. 알 수 없으면 30.
    let frameRate: Double
    let thumbnail: NSImage?

    init(url: URL, duration: TimeInterval, naturalSize: CGSize, frameRate: Double = 30) {
        self.url = url
        self.duration = duration
        self.naturalSize = naturalSize
        self.frameRate = frameRate
        self.thumbnail = nil
    }

    init(url: URL, duration: TimeInterval, naturalSize: CGSize, frameRate: Double = 30, thumbnail: NSImage?) {
        self.url = url
        self.duration = duration
        self.naturalSize = naturalSize
        self.frameRate = frameRate
        self.thumbnail = thumbnail
    }

    static func == (lhs: VideoSource, rhs: VideoSource) -> Bool {
        lhs.url == rhs.url &&
        lhs.duration == rhs.duration &&
        lhs.naturalSize == rhs.naturalSize
    }
}
