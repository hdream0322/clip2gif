import SwiftUI
import AppKit

struct ContentView: View {
    @State private var source: VideoSource?
    @State private var settings: ConversionSettings = .default
    @StateObject private var job = ConversionJob()
    @StateObject private var preview = PreviewController()
    /// 사용자가 직접 고른 출력 폴더(있으면 우선). 없으면 매번 원본 영상 폴더에 저장.
    @State private var customOutputDir: URL?
    @State private var alertError: ConversionError?
    @State private var showTrashConfirm = false
    @State private var preflightBytes: Int64?
    @State private var preflightLoading: Bool = false
    @State private var preflightTask: Task<Void, Never>?
    @State private var lastPreflightKey: String = ""
    /// 진행 중인 변환 Task. 취소 시 cancel() 로 추출 루프·gifski 를 중단.
    @State private var conversionTask: Task<Void, Never>?

    // 자주 쓰는 출력 설정을 영속화 — 영상마다 .default 로 초기화되던 마찰 제거.
    // (trim/crop/fps 는 영상 의존이라 영속 대상에서 제외)
    @AppStorage("pref.quality") private var prefQuality: Int = ConversionSettings.default.quality
    @AppStorage("pref.speed") private var prefSpeed: Double = ConversionSettings.default.speed
    @AppStorage("pref.scalePercent") private var prefScalePercent: Int = ConversionSettings.default.scalePercent
    @AppStorage("pref.loopForever") private var prefLoopForever: Bool = ConversionSettings.default.loopForever
    @AppStorage("pref.bounce") private var prefBounce: Bool = ConversionSettings.default.bounce

    /// 출력 파일 크기에 영향을 주는 설정만 모은 키. 이 값이 바뀔 때만 재추정.
    /// loopForever(무한반복)는 GIF 반복 플래그라 크기 불변 → 의도적으로 제외.
    private var preflightKey: String {
        guard let s = source else { return "none" }
        return [
            s.url.path,
            "\(settings.fps)",
            "\(settings.quality)",
            "\(settings.scalePercent)",
            "\(settings.trimStart)",
            "\(settings.trimEnd)",
            "\(settings.speed)",
            "\(settings.bounce)",
            "\(settings.cropRect)"
        ].joined(separator: "|")
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                leftPane
                    .frame(width: geo.size.width * 2 / 3)
                Divider()
                rightPane
                    .frame(width: geo.size.width * 1 / 3)
            }
        }
        .alert("변환 실패", isPresented: Binding(
            get: { alertError != nil },
            set: { if !$0 { alertError = nil } }
        )) {
            Button("확인") { alertError = nil }
        } message: {
            Text(alertError?.errorDescription ?? "알 수 없는 오류가 발생했습니다.")
        }
        .alert("원본 영상 파일을 휴지통으로 이동할까요?", isPresented: $showTrashConfirm) {
            Button("취소", role: .cancel) { }
            Button("휴지통으로 이동", role: .destructive) { deleteSourceToTrash() }
        } message: {
            Text("원본 영상 파일이 휴지통으로 이동됩니다. 변환에 사용할 영상이라면 주의하세요.")
        }
        .onChange(of: settings) { _ in
            // 사용자 선호 영속화 (다음 영상 로드 시 복원). 영상이 있을 때만 —
            // "파일 변경"/휴지통의 settings=.default 리셋이 선호값을
            // 덮어쓰지 않도록 한다(그 경로는 source 가 먼저 nil 이 됨).
            if source != nil {
                prefQuality = settings.quality
                prefSpeed = settings.speed
                prefScalePercent = settings.scalePercent
                prefLoopForever = settings.loopForever
                prefBounce = settings.bounce
            }
            if let s = source {
                preview.setRange(
                    start: settings.trimStart,
                    end: settings.effectiveTrimEnd(duration: s.duration)
                )
            }
            preview.setSpeed(settings.speed)
            preview.setBounce(settings.bounce)
            // 파일 크기에 영향 주는 설정이 바뀔 때만 재추정.
            // (무한반복 같은 메타 플래그 변경은 크기 불변 → 재계산 생략)
            let key = preflightKey
            if key != lastPreflightKey {
                lastPreflightKey = key
                schedulePreflight()
            }
        }
        .onChange(of: source) { _ in
            preflightBytes = nil
            lastPreflightKey = preflightKey
            schedulePreflight()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vtgOpenVideoFile)) { note in
            if let url = note.object as? URL { loadVideo(url: url) }
        }
        .onAppear {
            if let url = PendingOpenStore.shared.consume() { loadVideo(url: url) }
        }
        .onDrop(of: [.movie, .fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url") { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    let validExts = ["mp4", "mov", "m4v", "avi", "webm"]
                    if validExts.contains(url.pathExtension.lowercased()) {
                        DispatchQueue.main.async { loadVideo(url: url) }
                    }
                }
                return true
            }
            return false
        }
    }

    @ViewBuilder
    private var leftPane: some View {
        VStack(spacing: 12) {
            if let source {
                previewArea(source: source)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                metadataRow(source: source)
                HStack(spacing: 8) {
                    Button {
                        preview.setRange(
                            start: settings.trimStart,
                            end: settings.effectiveTrimEnd(duration: source.duration)
                        )
                        preview.setSpeed(settings.speed)
                        preview.setBounce(settings.bounce)
                        preview.togglePlay()
                    } label: {
                        Label(
                            preview.isPlaying ? "일시정지" : "재생",
                            systemImage: preview.isPlaying ? "pause.fill" : "play.fill"
                        )
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.space, modifiers: [])

                    Button {
                        settings.aspectLock = .free
                        settings.cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                    } label: {
                        Label("크롭 리셋", systemImage: "crop")
                    }
                    .buttonStyle(.bordered)
                    .disabled(settings.isFullFrame && settings.aspectLock == .free)

                    Menu {
                        ForEach(AspectLock.allCases) { lock in
                            Button {
                                applyAspectLock(lock, source: source)
                            } label: {
                                if settings.aspectLock == lock {
                                    Label(lock.label, systemImage: "checkmark")
                                } else {
                                    Text(lock.label)
                                }
                            }
                        }
                    } label: {
                        Label(
                            settings.aspectLock == .free ? "비율" : settings.aspectLock.label,
                            systemImage: "aspectratio"
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("크롭 박스를 자주 쓰는 비율로 고정")

                    Spacer()

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([source.url])
                    } label: {
                        Label("Finder에서 보기", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .help("원본 영상 위치를 Finder에서 열기")

                    Button {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.writeObjects([source.url as NSURL])
                    } label: {
                        Label("복사", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .help("원본 영상 파일을 클립보드에 복사")

                    Button(role: .destructive) {
                        showTrashConfirm = true
                    } label: {
                        Label("휴지통", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .help("원본 영상을 휴지통으로 이동")

                    Button {
                        self.source = nil
                        self.settings = .default
                        self.job.state = .idle
                        self.customOutputDir = nil
                        self.preview.pause()
                    } label: {
                        Label("파일 변경", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                }

                TrimSlider(
                    startTime: $settings.trimStart,
                    endTime: Binding(
                        get: { settings.effectiveTrimEnd(duration: source.duration) },
                        set: { settings.trimEnd = $0 }
                    ),
                    duration: source.duration,
                    onScrub: { t in
                        preview.seek(to: t)
                    }
                )
                .padding(.horizontal, 4)
            } else {
                DropZoneView { url in
                    loadVideo(url: url)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(12)
    }

    // MARK: - 서브뷰

    @ViewBuilder
    private var rightPane: some View {
        VStack(spacing: 0) {
            SettingsPanel(
                settings: $settings,
                naturalSize: source?.naturalSize,
                videoFrameRate: source?.frameRate ?? 30
            )
                .frame(maxHeight: .infinity, alignment: .top)

            if let source = source {
                cropInfo(source: source)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                estimateInfo(source: source)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                outputDestinationRow(source: source)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            Divider()

            ConvertButton(
                job: job,
                start: {
                    conversionTask?.cancel()
                    conversionTask = Task { await convert() }
                },
                cancel: {
                    conversionTask?.cancel()
                }
            )
            .padding(16)
        }
    }

    @ViewBuilder
    private func previewArea(source: VideoSource) -> some View {
        let aspect = source.naturalSize.height > 0
            ? source.naturalSize.width / source.naturalSize.height
            : 16.0 / 9.0

        ZStack {
            PreviewView(controller: preview)
                .aspectRatio(aspect, contentMode: .fit)
                .background(Color.black)
                .cornerRadius(8)

            CropOverlayView(
                cropRect: $settings.cropRect,
                aspectRatio: settings.normalizedBoxRatio(for: source.naturalSize)
            )
                .aspectRatio(aspect, contentMode: .fit)
                .allowsHitTesting(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func metadataRow(source: VideoSource) -> some View {
        HStack(spacing: 16) {
            Label(
                "\(Int(source.naturalSize.width))×\(Int(source.naturalSize.height))",
                systemImage: "aspectratio"
            )
            Label(formatDuration(source.duration), systemImage: "clock")
            Spacer()
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func cropInfo(source: VideoSource) -> some View {
        let outSize = settings.pixelOutputSize(for: source.naturalSize)
        VStack(alignment: .leading, spacing: 4) {
            Text("최종 출력")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Text("\(Int(outSize.width)) × \(Int(outSize.height)) px")
                .font(.body.monospacedDigit())
            HStack(spacing: 6) {
                if !settings.isFullFrame {
                    Text("크롭")
                        .font(.caption)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                if settings.scalePercent < 100 {
                    Text("축소 \(settings.scalePercent)%")
                        .font(.caption)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                if settings.bounce {
                    Text("왕복")
                        .font(.caption)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                if !settings.loopForever {
                    Text("1회")
                        .font(.caption)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func outputDestinationRow(source: VideoSource) -> some View {
        let dir = customOutputDir ?? source.url.deletingLastPathComponent()
        VStack(alignment: .leading, spacing: 4) {
            Text("저장 위치")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: customOutputDir == nil ? "folder" : "folder.fill")
                Text(dir.path)
                    .font(.callout.monospacedDigit())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("변경") { pickOutputDir() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                if customOutputDir != nil {
                    Button {
                        customOutputDir = nil
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("원본 영상 폴더로 되돌리기")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pickOutputDir() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "선택"
        panel.message = "GIF 저장 위치를 선택하세요"
        if panel.runModal() == .OK, let url = panel.url {
            customOutputDir = url
        }
    }

    @ViewBuilder
    private func estimateInfo(source: VideoSource) -> some View {
        let pixelRect = settings.pixelCropRect(for: source.naturalSize)
        let trimDuration = settings.effectiveTrimEnd(duration: source.duration) - settings.trimStart
        let outputDuration = trimDuration / max(0.1, settings.speed)
        let totalFrames = max(1, Int(outputDuration * Double(settings.fps)))
        let fallback = OutputEstimator.estimateRange(
            cropPixelSize: pixelRect.size,
            fps: settings.fps,
            durationSeconds: outputDuration,
            quality: settings.quality
        )

        VStack(alignment: .leading, spacing: 4) {
            Text("예상 결과")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Image(systemName: "doc")
                if let bytes = preflightBytes {
                    Text(OutputEstimator.formattedRoundedMB(bytes: Double(bytes)))
                        .monospacedDigit()
                    Text("(±10%)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(fallback.formatted)
                        .monospacedDigit()
                }
                if preflightLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 4)
                }
            }
            .font(.body)
            HStack {
                Image(systemName: "film")
                Text("\(totalFrames) 프레임 · \(String(format: "%.1f", outputDuration))초")
                    .monospacedDigit()
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            if preflightBytes == nil {
                Text("※ 실측 추정 진행 중 — 완료되면 정확값으로 갱신")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func schedulePreflight() {
        preflightTask?.cancel()
        guard let source = source, !job.isRunning else {
            preflightLoading = false
            return
        }
        let snapshot = settings
        preflightLoading = true
        preflightTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            if Task.isCancelled { return }
            do {
                let result = try await PreflightEstimator.estimate(
                    source: source, settings: snapshot
                )
                if Task.isCancelled { return }
                await MainActor.run {
                    self.preflightBytes = result.bytes
                    self.preflightLoading = false
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.preflightLoading = false
                }
            }
        }
    }

    // MARK: - 액션

    private func applyAspectLock(_ lock: AspectLock, source: VideoSource) {
        settings.aspectLock = lock
        guard let r = lock.pixelRatio else { return }
        settings.cropRect = ConversionSettings.centeredCropRect(
            pixelRatio: r, naturalSize: source.naturalSize
        )
    }

    private func deleteSourceToTrash() {
        guard let source else { return }
        NSWorkspace.shared.recycle([source.url]) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    alertError = .ioFailed(error.localizedDescription)
                    return
                }
                self.source = nil
                self.settings = .default
                self.job.state = .idle
                self.customOutputDir = nil
                self.preview.pause()
            }
        }
    }

    private func loadVideo(url: URL) {
        Task {
            do {
                let loaded = try await VideoLoader.load(url: url)
                source = loaded
                var s = ConversionSettings.default
                // 영속된 사용자 선호 적용 (영상마다 리셋되던 마찰 제거).
                s.quality = prefQuality
                s.speed = prefSpeed
                s.scalePercent = prefScalePercent
                s.loopForever = prefLoopForever
                s.bounce = prefBounce
                s.trimEnd = loaded.duration
                // 기본 FPS는 항상 원본 영상 프레임율과 동일하게.
                s.fps = max(6, Int(loaded.frameRate.rounded()))
                settings = s
                preview.load(url: loaded.url)
            } catch let e as ConversionError {
                alertError = e
            } catch {
                alertError = .ioFailed(error.localizedDescription)
            }
        }
    }

    private func convert() async {
        guard let source else { return }

        let baseDir = customOutputDir ?? source.url.deletingLastPathComponent()
        let stem = source.url.deletingPathExtension().lastPathComponent + "_converted"
        let outputURL = Self.uniqueOutputURL(in: baseDir, stem: stem, ext: "gif")

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            await MainActor.run { alertError = .ioFailed(error.localizedDescription) }
            return
        }

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let trimDuration = settings.effectiveTrimEnd(duration: source.duration) - settings.trimStart
        let outputDuration = trimDuration / max(0.1, settings.speed)
        let totalFrames = max(1, Int(outputDuration * Double(settings.fps)))

        await MainActor.run {
            job.reset()
            job.startedAt = Date()
            job.totalFrames = totalFrames
            job.stepName = "1/2 프레임 추출 중"
            job.detail = "0 / \(totalFrames) 프레임"
            job.state = .extracting(progress: 0)
            DockProgress.set(0.001)
        }

        do {
            let frames = try await FrameExtractor.extract(
                from: source,
                settings: settings,
                outputDir: tempDir
            ) { p in
                Task { @MainActor in
                    let current = Int(Double(totalFrames) * p)
                    job.currentFrame = current
                    job.detail = "\(current) / \(totalFrames) 프레임"
                    job.state = .extracting(progress: p)
                    DockProgress.set(job.overallProgress)
                }
            }

            await MainActor.run {
                job.stepName = "2/2 GIF 인코딩 중"
                job.currentFrame = 0
                job.detail = "0 / \(totalFrames) 프레임"
                job.state = .encoding(progress: 0)
                DockProgress.set(job.overallProgress)
            }

            try await GifskiEncoder.encode(
                frames: frames,
                settings: settings,
                naturalSize: source.naturalSize,
                output: outputURL
            ) { p in
                Task { @MainActor in
                    let current = Int(Double(totalFrames) * p)
                    job.currentFrame = current
                    job.detail = "\(current) / \(totalFrames) 프레임"
                    job.state = .encoding(progress: p)
                    DockProgress.set(job.overallProgress)
                }
            }

            await MainActor.run {
                job.stepName = "완료"
                job.detail = ""
                job.state = .done(outputURL)
                DockProgress.set(nil)
                // Finder 자동 노출은 제거 — 결과를 앱 내에서 바로 미리보고,
                // 필요 시 완료 블록의 "Finder에서 보기" 버튼으로 연다.
            }
        } catch let e as ConversionError {
            await MainActor.run {
                if e == .cancelled {
                    // 사용자가 의도적으로 취소 → 경고창 없이 조용히 초기화.
                    job.reset()
                } else {
                    job.state = .failed(e)
                    alertError = e
                }
                DockProgress.set(nil)
            }
        } catch is CancellationError {
            await MainActor.run {
                job.reset()
                DockProgress.set(nil)
            }
        } catch {
            let e = ConversionError.ioFailed(error.localizedDescription)
            await MainActor.run {
                job.state = .failed(e)
                DockProgress.set(nil)
                alertError = e
            }
        }
    }

    // MARK: - 헬퍼

    /// 같은 이름이 이미 있으면 `_2`, `_3` … 을 붙여 덮어쓰기를 방지한다.
    /// (같은 영상을 다른 설정으로 재변환할 때 이전 결과가 사라지지 않도록)
    private static func uniqueOutputURL(in dir: URL, stem: String, ext: String) -> URL {
        let fm = FileManager.default
        let first = dir.appendingPathComponent("\(stem).\(ext)")
        if !fm.fileExists(atPath: first.path) { return first }
        var n = 2
        while true {
            let candidate = dir.appendingPathComponent("\(stem)_\(n).\(ext)")
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return m > 0 ? "\(m)분 \(s)초" : "\(s)초"
    }
}
