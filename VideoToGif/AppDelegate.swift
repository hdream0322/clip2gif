import AppKit

extension Notification.Name {
    static let vtgOpenVideoFile = Notification.Name("VTGOpenVideoFile")
}

/// Service / "Open With" 진입점에서 받은 비디오 URL을 보관·재생.
/// SwiftUI 뷰가 onReceive를 구독하기 전에 도착한 URL도 onAppear 시점에 소비할 수 있도록 큐잉한다.
final class PendingOpenStore {
    static let shared = PendingOpenStore()
    private let lock = NSLock()
    private var url: URL?

    func push(_ u: URL) {
        lock.lock(); url = u; lock.unlock()
        NotificationCenter.default.post(name: .vtgOpenVideoFile, object: u)
    }

    func consume() -> URL? {
        lock.lock(); defer { lock.unlock() }
        let u = url; url = nil; return u
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
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
