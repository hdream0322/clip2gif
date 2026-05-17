<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-27 | Updated: 2026-05-17 -->

# VideoToGif (앱 소스)

## Purpose
앱의 모든 Swift 소스. SwiftUI 진입점 + AppDelegate(Service/"Open With" 핸들러) + ContentView 컨테이너 + Models/Services/Views 3계층 구조.

## Key Files
| File | Description |
|------|-------------|
| `VideoToGifApp.swift` | @main 진입점. `@NSApplicationDelegateAdaptor`로 AppDelegate 연결. WindowGroup, 최소(720×480)/기본(1100×720) 윈도우 크기 |
| `AppDelegate.swift` | NSApplicationDelegate. `servicesProvider` 등록 + `convertToGIF` 서비스 핸들러 + `application(_:open:)` "Open With". `PendingOpenStore`(싱글톤·NSLock)가 뷰 onAppear 이전 도착 URL을 큐잉, `.vtgOpenVideoFile` 노티로 전달 |
| `ContentView.swift` | 메인 컨테이너. 2/3+1/3 좌우 분할, 변환 파이프라인(FrameExtractor → GifskiEncoder), 프리플라이트 용량 추정, DockProgress 갱신, 출력 폴더 선택, 원본 휴지통/복사/Finder, 크롭 비율 고정, 드롭/서비스/Open-With 처리 |
| `Info.plist` | project.yml의 info.properties로 생성·관리 (직접 편집 금지) |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `Models/` | 도메인 데이터 타입 (see `Models/AGENTS.md`) |
| `Services/` | 비즈니스 로직 (영상 로딩/프레임 추출/GIF 인코딩/용량 추정/도크 진행률) (see `Services/AGENTS.md`) |
| `Views/` | SwiftUI 컴포넌트 (드롭존/트림/크롭/프리뷰/설정/변환 버튼) (see `Views/AGENTS.md`) |
| `Resources/` | 번들 자원. `bin/gifski` 외부 바이너리. xcodegen sources에서 제외됨 |
| `en.lproj/`, `ko.lproj/` | 다국어 리소스 디렉터리 |

## For AI Agents

### Working In This Directory
- 모든 Swift 파일은 단일 타겟·단일 모듈 → `import` 없이 같은 모듈 내 타입 직접 참조
- UI 문자열은 한국어, 코드/주석은 영어 우선(한국어 도메인 용어는 유지)
- ContentView 변환 파이프라인 수정 시 `ConversionJob`의 `stepName/detail/currentFrame/totalFrames/state` 갱신 필수 (UI 진행 표시 + DockProgress 직결)
- 외부 진입점(드롭/서비스/Open-With)은 모두 `loadVideo(url:)`로 수렴 — 새 진입점 추가 시 이 함수 재사용
- `preflightKey`는 출력 크기에 영향을 주는 설정만 모음. 크기 불변 플래그(loopForever 등)는 의도적으로 제외 — 새 설정 추가 시 분류 판단 필요

### Testing Requirements
- 변경 후 Xcode ⌘R로 mp4/mov 샘플 1개 정상 변환 확인
- 큰 영상(1080p+) 1회는 메모리 폭주 없는지 확인 (Activity Monitor)
- 도크 아이콘 진행률 링, 변환 후 Finder 자동 선택 동작 확인

### Common Patterns
- @MainActor: ConversionJob, PreviewController, DockProgress
- @StateObject는 ContentView에서만 (job, preview)
- @Published 상태 + ObservableObject 흐름
- Process 기반 외부 바이너리 호출은 GifskiEncoder만 사용
- 진행률 추정/프리플라이트는 취소 가능한 Task로 디바운스(600ms)

## Dependencies

### External
- AVFoundation, AVKit, AppKit, SwiftUI, CoreImage, ImageIO, CoreGraphics, UniformTypeIdentifiers

<!-- MANUAL: -->
