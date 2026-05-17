import Foundation
import CoreGraphics

/// 지원 비디오 형식의 단일 소스 of truth.
/// (드롭/Finder 서비스/Open With/파일 패널 세 곳에 하드코딩 복제돼 있던 것을 통합)
enum SupportedVideo {
    static let extensions: [String] = ["mp4", "mov", "m4v", "avi", "webm"]
    static let extensionSet: Set<String> = Set(extensions)

    static func isSupported(_ url: URL) -> Bool {
        extensionSet.contains(url.pathExtension.lowercased())
    }

    /// 사용자 안내용 표기. 예: "MP4, MOV, M4V, AVI, WebM"
    static let displayList = "MP4, MOV, M4V, AVI, WebM"
}

struct VideoSource: Identifiable, Equatable {
    var id: URL { url }
    let url: URL
    let duration: TimeInterval
    let naturalSize: CGSize
    /// 원본 영상의 초당 프레임 수. 알 수 없으면 30.
    let frameRate: Double

    init(url: URL, duration: TimeInterval, naturalSize: CGSize, frameRate: Double = 30) {
        self.url = url
        self.duration = duration
        self.naturalSize = naturalSize
        self.frameRate = frameRate
    }

    static func == (lhs: VideoSource, rhs: VideoSource) -> Bool {
        lhs.url == rhs.url &&
        lhs.duration == rhs.duration &&
        lhs.naturalSize == rhs.naturalSize
    }
}
