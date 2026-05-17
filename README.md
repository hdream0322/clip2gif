# Clip2GIF

macOS용 동영상 → GIF 변환 앱입니다. 비디오를 드래그하거나 Finder에서 바로 불러와 구간·영역·품질을 조정하고 GIF로 내보냅니다. 네이티브 SwiftUI 앱이며, 프레임 추출은 AVFoundation, 인코딩은 번들된 [gifski](https://gif.ski) 바이너리를 사용합니다.

## 주요 기능

- **구간 자르기 (Trim)** — 시작/끝 지점을 슬라이더로 지정
- **영역 잘라내기 (Crop)** — 정규화 좌표 기반, 비율 고정 옵션
- **출력 제어** — FPS·해상도·품질 조정
- **왕복 재생 (Bounce)** — gifski 네이티브 `--bounce`로 정주행 후 역주행 루프
- **실시간 프리뷰** — 변환 전 결과 미리보기 (역재생 포함)
- **출력 용량 추정** — 즉시 정적 추정 후, 실제 인코딩 표본으로 ±10% 정밀 재추정
- **진행률 표시** — 창 UI + Dock 아이콘 진행률 링 동시 반영
- **다중 진입점** — 드래그&드롭 · Finder 우클릭 서비스("GIF으로 변환하기") · "다음으로 열기"

## 요구 사항

- macOS 13.0 이상
- Xcode 15 이상
- [Homebrew](https://brew.sh)

## 설정

```bash
# 의존성 설치 (최초 1회)
brew install xcodegen gifski

# 프로젝트 초기화 (gifski 바이너리 복사 + .xcodeproj 생성)
./scripts/bootstrap.sh

# Xcode로 열기
open Clip2GIF.xcodeproj
```

`.xcodeproj`와 `Info.plist`는 `project.yml`에서 생성되는 산출물입니다. 직접 편집하지 말고, 새 `.swift` 파일을 추가/삭제했다면 `xcodegen generate`를 다시 실행하세요.

## 빌드 & 실행

- **Xcode**: `open Clip2GIF.xcodeproj` → ⌘B 컴파일 / ⌘R 실행 (캐시 꼬임 시 ⇧⌘K)
- **헤드리스**: `xcodebuild -project Clip2GIF.xcodeproj -scheme Clip2GIF build`

빌드에 성공하면 앱이 `/Applications/Clip2GIF.app`에 자동 설치되고 Launch Services가 갱신되어, Finder "다음으로 열기"·우클릭 서비스에서 바로 검증할 수 있습니다.

## 사용법

1. 앱에 동영상을 드래그하거나, Finder에서 동영상을 우클릭 → **GIF으로 변환하기** 선택
2. 구간(Trim)·영역(Crop)·FPS·품질·왕복 여부 설정
3. 프리뷰로 결과 확인, 예상 용량 참고
4. 변환 → GIF 저장

## 지원 포맷

입력: `mp4` · `mov` · `m4v` · `avi` · `webm`

## 아키텍처

단일 타겟·단일 모듈 SwiftUI 앱. **Models**(값 타입·상태) → **Services**(변환 로직) → **Views**(SwiftUI) 3계층 + `AppDelegate`(서비스/"열기" 진입점) 구조입니다. 변환 파이프라인은 `FrameExtractor`(PNG 직렬 추출) → `GifskiEncoder`(gifski 프로세스 실행) 순으로 흐르며, 진행률은 `ConversionJob`이 UI와 Dock에 중계합니다. 상세 구조는 루트 [`AGENTS.md`](AGENTS.md)부터 시작하는 계층형 문서를 참조하세요.

## 라이선스

개인용 프로젝트입니다. 코드 서명·notarization 없이 로컬 빌드로 사용합니다.
