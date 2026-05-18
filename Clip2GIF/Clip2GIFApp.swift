import SwiftUI
import Sparkle

@main
struct Clip2GIFApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    private let updater: SPUStandardUpdaterController = UpdaterManager.shared.controller

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 720, minHeight: 480)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updater.updater)
            }
            CommandGroup(replacing: .newItem) {
                Button("열기…") {
                    NotificationCenter.default.post(name: .vtgRequestOpenFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            // 기본 Help 메뉴 항목을 우리 도움말 창으로 대체.
            CommandGroup(replacing: .help) {
                Button("Clip2GIF 도움말") {
                    openWindow(id: "help")
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }

        // 메뉴바 "도움말"에서 여는 별도 도움말 창.
        Window("Clip2GIF 도움말", id: "help") {
            HelpView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 860, height: 620)
    }
}
