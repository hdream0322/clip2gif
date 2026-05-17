# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

상세한 디렉터리별 구조는 루트 `AGENTS.md`부터 시작하는 계층형 문서를 참조 (각 디렉터리에 AGENTS.md 존재).

## Setup & Build

```bash
brew install xcodegen gifski        # 최초 1회
./scripts/bootstrap.sh              # gifski 바이너리 복사 + .xcodeproj 생성
```

- **새 `.swift` 파일을 추가/삭제하면 반드시 `xcodegen generate` 재실행** — `.xcodeproj`는 `project.yml`에서 생성되는 산출물이며 직접 편집 금지.
- `Clip2GIF/Info.plist`도 `project.yml`의 `info.properties`에서 생성됨 — 직접 편집 금지. NSServices/문서타입/다국어는 `project.yml`에서 수정.
- GUI 빌드: `open Clip2GIF.xcodeproj` → ⌘B 컴파일 / ⌘R 실행. 캐시 꼬임 시 ⇧⌘K.
- 헤드리스 빌드: `xcodebuild -project Clip2GIF.xcodeproj -scheme Clip2GIF build`
- 빌드 성공 시 postBuildScript가 앱을 **`/Applications`에 자동 설치**하고 Launch Services를 갱신함 (Finder "Open With"/서비스 검증용).
- **테스트 스위트 없음** — 개인용 프로젝트. 검증은 실제 영상으로 ⌘R 수동 변환 + Activity Monitor 메모리 확인.

## Architecture

macOS 네이티브 SwiftUI 앱. **단일 타겟·단일 모듈** → 같은 모듈 내 타입은 `import` 없이 직접 참조.

**3계층 + 진입점**: `Models/`(값 타입·상태) → `Services/`(로직, 정적 함수/enum 네임스페이스) → `Views/`(SwiftUI). `AppDelegate.swift`가 Service/"Open With" 진입점.

**변환 파이프라인** (`ContentView.convert()`가 오케스트레이션):
`FrameExtractor`(AVAssetImageGenerator로 PNG 직렬 추출) → `GifskiEncoder`(번들 gifski 바이너리를 Process로 실행) → 출력 GIF. 진행률은 `ConversionJob`(@MainActor ObservableObject)의 `state`/`overallProgress`로 흐르고 UI + `DockProgress`(도크 아이콘 링)에 동시 반영.

**진입점 수렴**: 드래그&드롭 / Finder 서비스 / "Open With"는 모두 `loadVideo(url:)`로 수렴. 서비스/Open-With URL은 `PendingOpenStore`(싱글톤)가 큐잉해 뷰 `onAppear` 이전 도착분도 소비.

**용량 추정 2종**: `OutputEstimator`(인코딩 없는 정적 범위 추정, 즉시 폴백) → `PreflightEstimator`(작은/큰 윈도우를 실제 gifski로 인코딩 후 2점 선형회귀, ±10%, 600ms 디바운스 Task). `ContentView.preflightKey`가 출력 크기에 영향 주는 설정만 추려 재추정 트리거.

**좌표계**: 크롭은 정규화 좌표(0~1)로 저장. 픽셀 변환·짝수 정렬·비율 고정 계산은 전부 `ConversionSettings` 헬퍼(`pixelCropRect`/`pixelOutputSize`/`normalizedBoxRatio`/`centeredCropRect`)에 집중 — 뷰에서 직접 계산 금지.

## Hard Constraints

- **macOS 13 타겟**: `onChange(of:)`는 단일 파라미터 형태만 (`{ newValue in }`). `.foregroundStyle(.accent)` 미지원 → `Color.accentColor`. macOS 14 전용 API는 `#available` 분기 필수.
- **메모리**: 프레임 추출은 직렬 동기 + per-frame `autoreleasepool` 필수. `generateCGImagesAsynchronously` 일괄 사용 금지 (고해상도에서 10GB+ 폭주 사례).
- **gifski 접근**: `Bundle.main.url(forResource: "gifski", withExtension: nil)` — subdirectory 사용 금지. 바이너리 원본은 `Clip2GIF/Resources/bin/gifski`, postBuildScript가 번들로 복사.
- **bounce(왕복)**: gifski 네이티브 `--bounce` 플래그로만 처리. 프레임 역순 수동 첨부 시 gifski가 파일명을 재정렬해 절반 속도 버그 발생.
- **프리뷰 역재생**: AVPlayer 음수 rate 사용 금지 (키프레임만 디코딩되어 끊김). `PreviewController`는 30Hz 타이머 시킹으로 구현.
- 코드 서명·notarization 비활성, App Sandbox OFF (Process 실행 + NSWorkspace 휴지통/Finder 조작 위함).
- 모든 사용자 표시 문자열은 한국어. 진행률/UI 콜백은 메인 스레드 디스패치 필수.

## Convention

- SourceKit이 단일 파일 검사 시 cross-file 타입을 "Cannot find"로 오표시할 수 있음 — 실제 컴파일 결과로만 판단.
- 코드/주석은 영어 우선, 한국어 도메인 용어는 유지. 수치 표시는 `.monospacedDigit()`.
