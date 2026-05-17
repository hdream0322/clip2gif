import AppKit

extension Notification.Name {
    static let vtgOpenVideoFile = Notification.Name("VTGOpenVideoFile")
    /// ⌘O 등으로 "파일 열기" 패널 요청 (ContentView 가 수신해 NSOpenPanel 표시).
    static let vtgRequestOpenFile = Notification.Name("VTGRequestOpenFile")
}

/// Service / "Open With" 진입점에서 받은 비디오 URL을 보관·재생.
/// SwiftUI 뷰가 onReceive를 구독하기 전에 도착한 URL도 onAppear 시점에 소비할 수 있도록 큐잉한다.
final class PendingOpenStore {
    static let shared = PendingOpenStore()
    private let lock = NSLock()
    private var queue: [URL] = []

    func push(_ u: URL) {
        lock.lock(); queue.append(u); lock.unlock()
        NotificationCenter.default.post(name: .vtgOpenVideoFile, object: nil)
    }

    /// 누적된 모든 URL 을 비우며 반환 (단일/다중 파일 모두 보존 — 마지막
    /// 하나만 남던 버그 수정. 호출부가 1개=단일, N개=배치로 분기).
    func consumeAll() -> [URL] {
        lock.lock(); defer { lock.unlock() }
        let all = queue; queue = []; return all
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        Self.purgeStaleTempDirs()
    }

    /// 변환/프리플라이트 중 강제 종료(크래시·SIGKILL) 시 남는 임시 디렉터리를
    /// 시작할 때 청소. 프리픽스가 있는 우리 디렉터리만 안전하게 제거한다.
    private static func purgeStaleTempDirs() {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
        guard let entries = try? fm.contentsOfDirectory(
            at: tmp, includingPropertiesForKeys: nil
        ) else { return }
        for url in entries {
            let name = url.lastPathComponent
            if name.hasPrefix("clip2gif-") || name.hasPrefix("preflight-") {
                try? fm.removeItem(at: url)
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { handle(url: url) }
    }

    @objc func convertToGIF(_ pboard: NSPasteboard,
                            userData: String,
                            error errorPointer: AutoreleasingUnsafeMutablePointer<NSString>) {
        let validExts: Set<String> = ["mp4", "mov", "m4v", "avi", "webm"]
        var urls: [URL] = []
        if let items = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            urls.append(contentsOf: items)
        }
        if urls.isEmpty, let names = pboard.propertyList(forType: .init("NSFilenamesPboardType")) as? [String] {
            urls.append(contentsOf: names.map { URL(fileURLWithPath: $0) })
        }
        let filtered = urls.filter { validExts.contains($0.pathExtension.lowercased()) }
        guard !filtered.isEmpty else {
            errorPointer.pointee = "선택된 항목 중 지원되는 비디오 파일이 없습니다." as NSString
            return
        }
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            for url in filtered { self.handle(url: url) }
        }
    }

    private func handle(url: URL) {
        DispatchQueue.main.async {
            PendingOpenStore.shared.push(url)
        }
    }
}
