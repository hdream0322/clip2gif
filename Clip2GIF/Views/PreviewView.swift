import SwiftUI
import AVKit

/// AVPlayerView를 SwiftUI에 래핑. 외부에서 `controller`를 통해 재생/시킹 제어.
struct PreviewView: NSViewRepresentable {
    let controller: PreviewController

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = false
        view.videoGravity = .resizeAspect
        view.player = controller.player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== controller.player {
            nsView.player = controller.player
        }
    }
}

/// AVPlayer 라이프사이클 + 트림 구간 무한 루프 재생.
@MainActor
final class PreviewController: ObservableObject {
    let player = AVPlayer()
    @Published var isPlaying: Bool = false

    private var rangeStart: TimeInterval = 0
    private var rangeEnd: TimeInterval = 0
    private var currentSpeed: Double = 1.0
    private var currentBounce: Bool = false
    private var loopObserver: Any?

    // 역재생(왕복)용 타이머 스텝. AVPlayer 음수 rate는 키프레임만 디코딩해
    // 끊기므로, 프레임 단위 시킹을 일정 주기로 수행해 부드럽게 되감는다.
    private var reverseTimer: Timer?
    private var reverseTime: TimeInterval = 0
    private let reverseHz: Double = 30

    init() {
        player.isMuted = true
        player.actionAtItemEnd = .pause
    }

    deinit {
        if let loopObserver {
            player.removeTimeObserver(loopObserver)
        }
        reverseTimer?.invalidate()
    }

    func load(url: URL) {
        stopReverse()
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.pause()
        isPlaying = false
    }

    /// 현재 재생 위치(초). "현재 위치를 시작/끝으로" 버튼이 사용.
    var currentSeconds: TimeInterval {
        let t = CMTimeGetSeconds(player.currentTime())
        return t.isFinite ? max(0, t) : 0
    }

    func seek(to seconds: TimeInterval) {
        let time = CMTimeMakeWithSeconds(seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// 트림 구간을 갱신. 재생 중이고 현재 위치가 범위 밖이면 시작점으로 시킹.
    func setRange(start: TimeInterval, end: TimeInterval) {
        rangeStart = start
        rangeEnd = max(start + 0.05, end)
        stopReverse()
        rebindLoopObserver()
        if isPlaying {
            let cur = CMTimeGetSeconds(player.currentTime())
            if cur < rangeStart || cur >= rangeEnd {
                seek(to: rangeStart)
            }
        }
    }

    /// 배속을 즉시 적용. 정방향 재생 중이면 rate 갱신.
    /// 역재생 중이면 타이머가 매 틱 currentSpeed를 읽으므로 별도 처리 불필요.
    func setSpeed(_ speed: Double) {
        currentSpeed = max(0.1, speed)
        if isPlaying && reverseTimer == nil {
            player.rate = Float(currentSpeed)
        }
    }

    /// 왕복(bounce) 미리보기 on/off. 켜면 끝에서 역재생으로 되돌아옴.
    func setBounce(_ on: Bool) {
        currentBounce = on
        if !on { stopReverse() }
        rebindLoopObserver()
    }

    func togglePlay() {
        if isPlaying { pause() } else { play() }
    }

    func play() {
        stopReverse()
        rebindLoopObserver()
        let cur = CMTimeGetSeconds(player.currentTime())
        if cur < rangeStart || cur >= rangeEnd - 0.01 {
            seek(to: rangeStart)
        }
        player.rate = Float(currentSpeed)
        isPlaying = true
    }

    func pause() {
        stopReverse()
        player.pause()
        isPlaying = false
    }

    /// 트림 끝 경계를 관찰. 일반 모드는 끝→처음 점프 루프,
    /// bounce 모드는 끝에서 타이머 역재생 시작(왕복).
    private func rebindLoopObserver() {
        if let loopObserver {
            player.removeTimeObserver(loopObserver)
            self.loopObserver = nil
        }
        let endTime = CMTimeMakeWithSeconds(rangeEnd, preferredTimescale: 600)
        loopObserver = player.addBoundaryTimeObserver(
            forTimes: [NSValue(time: endTime)],
            queue: .main
        ) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.handleBoundary()
            }
        }
    }

    private func handleBoundary() {
        // 역재생 중에는 player가 멈춰 있어 경계 콜백이 오지 않음.
        guard reverseTimer == nil else { return }
        let cur = CMTimeGetSeconds(player.currentTime())
        guard cur >= rangeEnd - 0.05 else { return }

        if currentBounce {
            startReverse()
        } else {
            let startCM = CMTimeMakeWithSeconds(rangeStart, preferredTimescale: 600)
            player.seek(to: startCM, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isPlaying else { return }
                    self.player.rate = Float(self.currentSpeed)
                }
            }
        }
    }

    // MARK: - 타이머 기반 부드러운 역재생

    private func startReverse() {
        stopReverse()
        player.pause()
        reverseTime = rangeEnd
        let timer = Timer(timeInterval: 1.0 / reverseHz, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.reverseStep()
            }
        }
        timer.tolerance = 1.0 / (reverseHz * 4)
        RunLoop.main.add(timer, forMode: .common)
        reverseTimer = timer
    }

    private func reverseStep() {
        reverseTime -= currentSpeed / reverseHz
        if reverseTime <= rangeStart {
            stopReverse()
            let startCM = CMTimeMakeWithSeconds(rangeStart, preferredTimescale: 600)
            player.seek(to: startCM, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isPlaying else { return }
                    self.player.rate = Float(self.currentSpeed)   // 정방향 재개
                }
            }
            return
        }
        let t = CMTimeMakeWithSeconds(reverseTime, preferredTimescale: 600)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func stopReverse() {
        reverseTimer?.invalidate()
        reverseTimer = nil
    }
}
