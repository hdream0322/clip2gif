<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-27 | Updated: 2026-05-17 -->

# Views

## Purpose
SwiftUI 뷰 컴포넌트. 드롭존, 트림 슬라이더, 비율 고정 크롭 오버레이, 비디오 프리뷰(왕복 역재생 포함), 설정 패널, 변환 버튼. ContentView가 최상위 컨테이너로 조합.

## Key Files
| File | Description |
|------|-------------|
| `DropZoneView.swift` | 드래그&드롭 + 클릭 시 NSOpenPanel(영상 필터). mp4/mov/m4v/avi/webm 검증 |
| `TrimSlider.swift` | GeometryReader 듀얼 핸들 슬라이더. 0.1초 스냅. `onScrub` 콜백으로 프리뷰 시킹 연동 |
| `CropOverlayView.swift` | 비디오 위 드래그 박스. 4모서리+4변 핸들, 박스 내부 드래그 이동. `aspectRatio` 지정 시 비율 유지(`conformCorner`/`conformEdge` — 모서리는 반대편 고정, 변은 중심 유지). cropRect 정규화 좌표(0~1) |
| `PreviewView.swift` | AVPlayerView NSViewRepresentable + `PreviewController`(@MainActor). seek/setRange/setSpeed/setBounce/togglePlay. 트림 구간 boundary 옵저버 루프, bounce 시 타이머 기반 부드러운 역재생(30Hz 시킹, AVPlayer 음수 rate 회피) |
| `SettingsPanel.swift` | Form. FPS 슬라이더(상한=원본 frameRate, 최소 5/6), 재생 속도(0.5~10 + 프리셋 버튼), 무한반복/왕복 토글, 출력 배율 Picker(100/75/50/25, naturalSize 있으면 px 표시), 화질 프리셋(원본100/높음85/보통70/낮음50/사용자지정) + 커스텀 슬라이더 |
| `ConvertButton.swift` | 진행 막대 + 스텝/프레임/경과/ETA, 완료 시 파일크기·이름, 실패 시 에러. 버튼 라벨/아이콘 상태별 분기 |

## For AI Agents

### Working In This Directory
- 모든 사용자 표시 문자열은 한국어
- macOS 13 타겟 → `onChange(of:)` 단일 파라미터(`{ newValue in ... }`)만 사용
- `.foregroundStyle(.accent)` 미지원 → `Color.accentColor` 사용
- CropOverlayView 좌표계: GeometryReader가 비디오 영역과 동일 크기여야 함 — 부모(ContentView previewArea)에서 PreviewView와 동일한 `.aspectRatio(aspect, contentMode: .fit)` 적용
- dim overlay ZStack은 반드시 `.topLeading` 정렬 (다른 정렬이면 좌표 어긋남)
- 비율 고정 시 `aspectRatio`는 "정규화 w/h" (= 출력픽셀비율 × H/W). ConversionSettings.normalizedBoxRatio가 산출 — 직접 계산 금지
- PreviewController의 bounce 역재생은 타이머 시킹(reverseHz=30). AVPlayer 음수 rate로 바꾸지 말 것(키프레임만 디코딩되어 끊김)
- SettingsPanel FPS 상한은 원본 frameRate 연동 — videoFrameRate 미전달 시 30 폴백

### Testing Requirements
- 트림 핸들 드래그 시 프리뷰 즉시 시킹
- 크롭 박스 4변/4모서리 리사이즈 + 내부 드래그 이동, 비율 고정 시 비율 유지
- "재생" + 왕복 토글 시 끝에서 부드럽게 역재생 후 정방향 재개
- 화질/배율/속도 변경 시 settings 즉시 갱신 + 예상 용량 재추정(600ms 디바운스)
- 윈도우 리사이즈 시 좌 2/3·우 1/3 비율 유지

### Common Patterns
- @Binding 양방향 연결, @StateObject는 ContentView에서만
- 핸들 제스처: 이동은 드래그 시작 원점 고정 후 누적 translation 1회 적용(가속 방지), 리사이즈는 포인터 절대 위치 사용
- 폰트: 헤더 `.subheadline.bold()`, 본문 `.body`, 보조 `.callout`, 미세 `.caption`, 수치는 `.monospacedDigit()`

## Dependencies

### Internal
- `Models/`: ConversionSettings, AspectLock, ConversionJob, ConversionState, ConversionError
- `Services/`: OutputEstimator (ConvertButton 파일 크기 포맷)

### External
- SwiftUI, AppKit, AVKit, UniformTypeIdentifiers

<!-- MANUAL: -->
