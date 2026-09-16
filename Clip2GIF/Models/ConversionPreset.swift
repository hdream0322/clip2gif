import Foundation
import Combine

/// 이름을 붙여 저장하는 출력 설정 프리셋.
///
/// 영상에 의존하는 값(trim/crop/aspectLock)은 의도적으로 제외 — 프리셋은
/// "어떤 영상에든 재사용 가능한 출력 취향"만 담는다. fps 는 영상 프레임율로
/// 상한이 잘리므로(SettingsPanel 의 maxFps) 저장하되 적용 시 클램프된다.
struct ConversionPreset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String

    var fps: Int
    var quality: Int
    var speed: Double
    var scalePercent: Int
    var loopForever: Bool
    var bounce: Bool
    var motionQuality: Int?
    var lossyQuality: Int?

    init(name: String, from s: ConversionSettings) {
        self.name = name
        self.fps = s.fps
        self.quality = s.quality
        self.speed = s.speed
        self.scalePercent = s.scalePercent
        self.loopForever = s.loopForever
        self.bounce = s.bounce
        self.motionQuality = s.motionQuality
        self.lossyQuality = s.lossyQuality
    }

    init(
        id: UUID = UUID(), name: String, fps: Int, quality: Int, speed: Double,
        scalePercent: Int, loopForever: Bool, bounce: Bool,
        motionQuality: Int? = nil, lossyQuality: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.fps = fps
        self.quality = quality
        self.speed = speed
        self.scalePercent = scalePercent
        self.loopForever = loopForever
        self.bounce = bounce
        self.motionQuality = motionQuality
        self.lossyQuality = lossyQuality
    }

    /// 현재 설정에 출력 취향만 덮어쓴다 (trim/crop/aspectLock 은 보존).
    func apply(to s: inout ConversionSettings) {
        s.fps = fps
        s.quality = quality
        s.speed = speed
        s.scalePercent = scalePercent
        s.loopForever = loopForever
        s.bounce = bounce
        s.motionQuality = motionQuality
        s.lossyQuality = lossyQuality
    }

    /// 자주 쓰는 시나리오용 기본 제공 프리셋 (삭제 불가, 적용 전용).
    static let builtIns: [ConversionPreset] = [
        ConversionPreset(
            name: "SNS 공유 (가벼움)", fps: 15, quality: 70,
            speed: 1.0, scalePercent: 75, loopForever: true, bounce: false
        ),
        ConversionPreset(
            name: "고화질 보관", fps: 30, quality: 100,
            speed: 1.0, scalePercent: 100, loopForever: true, bounce: false
        ),
        ConversionPreset(
            name: "초경량 (채팅용)", fps: 12, quality: 50,
            speed: 1.0, scalePercent: 50, loopForever: true, bounce: false,
            motionQuality: 40, lossyQuality: 50
        )
    ]
}

/// 사용자 프리셋을 UserDefaults(JSON)에 영속화하는 옵저버블 스토어.
final class PresetStore: ObservableObject {
    @Published private(set) var userPresets: [ConversionPreset] = []

    private let key = "userPresets.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([ConversionPreset].self, from: data)
        else { return }
        userPresets = list
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(userPresets) else { return }
        defaults.set(data, forKey: key)
    }

    /// 같은 이름이 있으면 덮어쓰고, 없으면 추가한다.
    func save(_ preset: ConversionPreset) {
        if let idx = userPresets.firstIndex(where: { $0.name == preset.name }) {
            var updated = preset
            updated.id = userPresets[idx].id
            userPresets[idx] = updated
        } else {
            userPresets.append(preset)
        }
        persist()
    }

    func delete(_ preset: ConversionPreset) {
        userPresets.removeAll { $0.id == preset.id }
        persist()
    }
}
