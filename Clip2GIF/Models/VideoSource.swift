import Foundation
import CoreGraphics
import UniformTypeIdentifiers

/// 드롭 프로바이더 처리의 단일 구현. ContentView.onDrop 과
/// DropZoneView.handleDrop 이 거의 동일한 로직을 복제하던 것을 통합.
enum VideoDrop {
    /// 첫 프로바이더에서 비디오 URL 을 로드. 처리 시작했으면 true.
    /// onAccept/onReject 는 메인 스레드로 디스패치되어 호출된다.
    @discardableResult
    static func handle(
        _ providers: [NSItemProvider],
        onAccept: @escaping (URL) -> Void,
        onReject: @escaping (URL) -> Void
    ) -> Bool {
        guard let provider = providers.first else { return false }

        func deliver(_ url: URL) {
            DispatchQueue.main.async {
                SupportedVideo.isSupported(url) ? onAccept(url) : onReject(url)
            }
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    deliver(url)
                }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.movie.identifier) { item, _ in
                if let url = item as? URL { deliver(url) }
            }
            return true
        }
        return false
    }

    /// 여러 프로바이더(다중 파일 드롭)에서 URL 을 모두 수집해 한 번에 전달.
    /// 비동기 로드가 모두 끝나면 메인 스레드에서 onCollected 1회 호출.
    @discardableResult
    static func handleAll(
        _ providers: [NSItemProvider],
        onCollected: @escaping ([URL]) -> Void
    ) -> Bool {
        let candidates = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                || $0.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
        }
        guard !candidates.isEmpty else { return false }

        let group = DispatchGroup()
        let lock = NSLock()
        var collected: [URL] = []

        for provider in candidates {
            group.enter()
            let done: (URL?) -> Void = { url in
                if let url {
                    lock.lock(); collected.append(url); lock.unlock()
                }
                group.leave()
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        done(url)
                    } else { done(nil) }
                }
            } else {
                provider.loadItem(forTypeIdentifier: UTType.movie.identifier) { item, _ in
                    done(item as? URL)
                }
            }
        }

        group.notify(queue: .main) {
            onCollected(collected)
        }
        return true
    }
}

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
