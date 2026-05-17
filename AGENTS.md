<!-- Generated: 2026-04-27 | Updated: 2026-05-17 -->

# Clip2GIF

## Purpose
macOS 네이티브 Video → GIF 변환 앱. SwiftUI 기반, AVFoundation으로 프레임 추출, 번들된 gifski 바이너리로 인코딩. 개인용(코드 서명/notarization 없음). Finder "Open With" + 우클릭 서비스("GIF으로 변환하기") 진입점 지원, 빌드 시 `/Applications`에 자동 설치.

## Key Files
| File | Description |
|------|-------------|
| `project.yml` | XcodeGen 프로젝트 정의. sources에서 `Resources/**`·`**/AGENTS.md` 제외. postBuildScripts 2개: gifski 번들 복사 + `/Applications` 설치. Info.plist에 NSServices·CFBundleDocumentTypes·다국어(en/ko/ja/zh-Hans/fr/de/es) 주입. bundleIdPrefix `com.heodream`, deployment 13.0, 서명 OFF |
| `scripts/bootstrap.sh` | 개발 환경 부트스트랩 (xcodegen/gifski 의존성 체크 + 바이너리 복사 + xcodegen generate) |
| `.gitignore` | Xcode/Swift 표준 + Resources/bin/gifski 바이너리 무시 |
| `README.md` | 한국어 사용 안내 |
| `Clip2GIF.xcodeproj/` | XcodeGen이 생성. 직접 편집 금지 — `xcodegen generate`로 재생성 |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `Clip2GIF/` | 앱 소스 코드 (see `Clip2GIF/AGENTS.md`) |
| `scripts/` | 빌드/셋업 스크립트 (see `scripts/AGENTS.md`) |
| `.omc/`, `.claude/` | 도구 생성 메타데이터 (추적 안 함) |

## For AI Agents

### Working In This Directory
- 새 .swift 파일 추가 시 `xcodegen generate` 재실행 필수 (.xcodeproj는 자동 생성물)
- gifski 바이너리는 `Clip2GIF/Resources/bin/gifski`에 위치, postBuildScript가 번들 Resources로 복사
- `Bundle.main.url(forResource: "gifski", withExtension: nil)`로 런타임 접근 — subdirectory 사용 금지
- macOS 13+ 타겟. `onChange(of:initial:_:)` 같은 macOS 14 API 사용 금지 (단일 파라미터 onChange만)
- 코드 서명·notarization 비활성. App Sandbox OFF (Process로 외부 바이너리 실행, NSWorkspace로 휴지통/Finder 조작)
- project.yml의 NSServices/CFBundleDocumentTypes를 바꾸면 `/Applications` 재설치 + `pbs -update` 후에야 Finder에 반영됨 (postBuildScript가 자동 수행)
- SourceKit이 단일 파일 검사 시 cross-file 타입을 "Cannot find"로 잘못 표시할 수 있음 — 실제 컴파일 결과로만 판단

### Testing Requirements
- Xcode에서 ⌘B로 컴파일, ⌘R로 실제 동작 확인
- 빌드 캐시가 꼬이면 `Shift+⌘+K` (Clean Build Folder) 후 재빌드
- "Open With"/서비스 진입점 변경 시 `/Applications` 빌드 산출물에서 Finder 우클릭으로 실제 검증
- 단위 테스트 없음 (개인용 프로젝트, 수동 검증)

### Common Patterns
- Swift 5.9, SwiftUI, AVFoundation, AppKit
- async/throws 동시성 모델, MainActor 격리
- 파일 구조: Models / Services / Views 3계층 + AppDelegate(진입점)

## Dependencies

### External
- **xcodegen** (Homebrew) - .xcodeproj 생성 도구
- **gifski** (Homebrew) - GIF 인코더 바이너리. 빌드 시 번들에 복사됨
- **AVFoundation / AVKit / AppKit / SwiftUI / CoreImage / ImageIO** (Apple) - 프레임워크

<!-- MANUAL: -->
