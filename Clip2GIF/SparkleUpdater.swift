import SwiftUI
import Sparkle

/// Sparkle 자동 업데이트 컨트롤러를 앱 수명주기 동안 보관한다.
/// `startingUpdater: true` 이므로 Info.plist의 SUEnableAutomaticChecks /
/// SUScheduledCheckInterval 설정에 따라 백그라운드 검사도 자동 수행된다.
final class UpdaterManager {
    static let shared = UpdaterManager()
    let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
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
