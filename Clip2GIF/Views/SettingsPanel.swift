import SwiftUI

struct SettingsPanel: View {
    @Binding var settings: ConversionSettings
    /// 출력 크기 안내 표시용 (없으면 % 만 표시).
    var naturalSize: CGSize? = nil
    /// 원본 영상 프레임율. FPS 슬라이더 상한.
    var videoFrameRate: Double = 30
    @State private var qualityPreset: QualityPreset = .high

    /// FPS 슬라이더 상한(원본 프레임율, 최소 6 보장).
    private var maxFps: Int { max(6, Int(videoFrameRate.rounded())) }

    enum QualityPreset: String, CaseIterable, Identifiable {
        case original = "원본"
        case high = "높음"
        case medium = "보통"
        case low = "낮음"
        case custom = "사용자 지정"

        var id: String { rawValue }

        var quality: Int? {
            switch self {
            case .original: return 100
            case .high: return 85
            case .medium: return 70
            case .low: return 50
            case .custom: return nil
            }
        }

        var description: String {
            switch self {
            case .original: return "원본 화질 그대로 (파일 큼)"
            case .high: return "약간 압축 — 일반 권장"
            case .medium: return "균형 — SNS 업로드용"
            case .low: return "강한 압축 — 작은 파일"
            case .custom: return ""
            }
        }
    }

    var body: some View {
        Form {
            Section("재생 설정") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("프레임율")
                        Spacer()
                        Text("\(settings.fps)/\(maxFps)fps")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: Binding(
                        get: { Double(min(settings.fps, maxFps)) },
                        set: { settings.fps = min(maxFps, max(5, Int($0))) }
                    ), in: 5...Double(maxFps), step: 1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("재생 속도")
                        Spacer()
                        Text(String(format: "%.1fx", settings.speed))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $settings.speed, in: 0.5...10, step: 0.5)
                    HStack(spacing: 4) {
                        ForEach([0.5, 1.0, 2.0, 4.0], id: \.self) { v in
                            Button(String(format: "%.1fx", v)) {
                                settings.speed = v
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                }

                Toggle("무한 반복", isOn: $settings.loopForever)
                Toggle("왕복(Bounce)", isOn: $settings.bounce)
                Text("왕복: 끝에 도달하면 역재생으로 처음까지 돌아옴 (프레임 약 2배).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("출력 크기") {
                Picker("배율", selection: $settings.scalePercent) {
                    ForEach([100, 75, 50, 25], id: \.self) { p in
                        if let natural = naturalSize {
                            let s = settings.pixelOutputSize(for: natural, scalePercent: p)
                            Text("\(p)% (\(Int(s.width))×\(Int(s.height))px)").tag(p)
                        } else {
                            Text("\(p)%").tag(p)
                        }
                    }
                }
                Text("가로/세로 비율은 유지. 작게 하면 파일이 더 가벼워짐.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("화질") {
                Picker("프리셋", selection: $qualityPreset) {
                    ForEach(QualityPreset.allCases) { preset in
                        Text(preset.quality.map { "\(preset.rawValue) (\($0))" } ?? preset.rawValue)
                            .tag(preset)
                    }
                }
                .onChange(of: qualityPreset) { newValue in
                    if let q = newValue.quality {
                        settings.quality = q
                    }
                }

                if !qualityPreset.description.isEmpty {
                    Text(qualityPreset.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Text("화질을 높이면 색을 더 많이 보존하고 압축을 약하게 해 또렷하지만 파일이 커집니다. 낮추면 색 수와 디테일을 줄여 파일이 가벼워집니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if qualityPreset == .custom {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("값")
                            Spacer()
                            Text("\(settings.quality)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: Binding(
                            get: { Double(settings.quality) },
                            set: { settings.quality = Int($0) }
                        ), in: 1...100, step: 1)
                    }
                }

                DisclosureGroup("고급 압축") {
                    advancedQualityRow(
                        title: "모션 품질",
                        help: "낮추면 프레임 간(시간) 압축이 강해져 용량이 줄지만 움직임이 거칠어집니다.",
                        value: $settings.motionQuality
                    )
                    advancedQualityRow(
                        title: "손실 품질",
                        help: "낮추면 프레임 내(공간) 압축이 강해져 용량이 줄지만 노이즈/스트릭이 생깁니다.",
                        value: $settings.lossyQuality
                    )
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            qualityPreset = matchedPreset(for: settings.quality)
        }
    }

    /// gifski 고급 옵션 1줄: 켜면 1~100 슬라이더, 끄면 nil(미지정=gifski 기본).
    @ViewBuilder
    private func advancedQualityRow(
        title: String,
        help: String,
        value: Binding<Int?>
    ) -> some View {
        let isOn = Binding(
            get: { value.wrappedValue != nil },
            set: { value.wrappedValue = $0 ? (value.wrappedValue ?? 60) : nil }
        )
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: isOn) {
                HStack {
                    Text(title)
                    Spacer()
                    if let v = value.wrappedValue {
                        Text("\(v)").foregroundStyle(.secondary).monospacedDigit()
                    } else {
                        Text("기본").foregroundStyle(.tertiary)
                    }
                }
            }
            if let v = value.wrappedValue {
                Slider(value: Binding(
                    get: { Double(v) },
                    set: { value.wrappedValue = Int($0) }
                ), in: 1...100, step: 1)
            }
            Text(help)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func matchedPreset(for value: Int) -> QualityPreset {
        for preset in QualityPreset.allCases {
            if preset.quality == value { return preset }
        }
        return .custom
    }
}
