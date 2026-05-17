import SwiftUI
import Sparkle

/// Sparkle 자동 업데이트 컨트롤러를 앱 수명주기 동안 보관한다.
/// `startingUpdater: true` 이므로 Info.plist의 SUEnableAutomaticChecks /
/// SUScheduledCheckInterval 설정에 따라 백그라운드 검사도 자동 수행된다.
///
/// SPUUpdaterDelegate 를 구현해 신뢰 정책을 코드로 강제한다(파이프라인
/// 침해/Info.plist 변조 시 2차 방어):
/// - feed URL 을 코드에 고정 — Info.plist 의 SUFeedURL 이 바뀌어도 무시
/// - 시스템 프로파일 전송 차단 — 업데이트 요청에 기기 정보를 싣지 않음
final class UpdaterManager: NSObject, SPUUpdaterDelegate {
    static let shared = UpdaterManager()

    /// project.yml(Info.plist)의 SUFeedURL 과 반드시 일치시킬 것.
    private static let pinnedFeedURL =
        "https://github.com/hdream0322/clip2gif/releases/latest/download/appcast.xml"

    private(set) var controller: SPUStandardUpdaterController!

    private override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        Self.pinnedFeedURL
    }

    func allowedSystemProfileKeys(for updater: SPUUpdater) -> [String]? {
        []
    }
}

/// "업데이트 확인…" 메뉴 항목의 활성/비활성 상태를 갱신하기 위한 뷰모델.
/// (Monterey 이전 macOS에서 메뉴 disabled 상태가 갱신되지 않는 SwiftUI 버그 우회용
///  중간 뷰가 필요하다 — Sparkle 공식 문서 권장 패턴.)
@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("업데이트 확인…", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}
