<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-27 | Updated: 2026-05-17 -->

# Models

## Purpose
앱의 도메인 데이터 타입. 값 타입 + ObservableObject 1개 + 보조 enum. 비즈니스 로직 없음 — 데이터 표현과 좌표/진행률 계산 헬퍼만.

## Key Files
| File | Description |
|------|-------------|
| `VideoSource.swift` | 로드된 비디오 메타. url/duration/naturalSize/`frameRate`/thumbnail. Identifiable+Equatable (썸네일 제외 비교). frameRate 기본값 30 |
| `ConversionSettings.swift` | 변환 옵션 struct + `AspectLock` enum(자유/1:1/4:3/3:4/16:9/9:16). trim/fps/quality/speed(0.5~10)/cropRect(정규화 0~1)/aspectLock/scalePercent(25·50·75·100)/loopForever/bounce. 헬퍼: `pixelCropRect`(짝수·최소2px) / `pixelOutputSize`(크롭+배율) / `isFullFrame` / `normalizedBoxRatio` / `centeredCropRect`(비율 유지 가운데 정렬) |
| `ConversionJob.swift` | @MainActor ObservableObject. `ConversionState`/`ConversionError` enum + @Published 진행상태(state/stepName/detail/startedAt/totalFrames/currentFrame). `extractWeight`(0.55) 기반 `overallProgress`, `stepProgress`, `isRunning`, `elapsedSeconds`, `etaSeconds`, `reset()` |

## For AI Agents

### Working In This Directory
- 새 필드 추가 시 ConversionSettings는 Equatable 유지 (UI 갱신·preflightKey 트리거용)
- `ConversionError` 케이스 추가 시 `errorDescription`에 한국어 메시지 함께 추가
- `ConversionJob` 필드 추가 시 `reset()`도 같이 갱신
- `ConversionState`는 `.extracting`/`.encoding`이 `isRunning`·`overallProgress` 분기에 직결 — 새 진행 단계 추가 시 두 곳 모두 갱신
- 정규화 좌표(0~1) ↔ 픽셀 변환은 반드시 ConversionSettings 헬퍼 경유 (짝수·최소 크기 보정이 한 곳에 모여 있음)
- `centeredCropRect`/`normalizedBoxRatio`의 비율은 "출력 픽셀 기준 w/h"이며 정규화 비율로 환산 시 `* H/W` 적용 — 공식 변경 주의

### Testing Requirements
- 모델 변경 시 ContentView convert() / 프리플라이트 / SettingsPanel이 새 필드를 갱신·소비하는지 확인
- 비율 고정 크롭은 4모서리·4변 드래그 모두 비율 유지되는지 확인

### Common Patterns
- struct 기본, ObservableObject는 ConversionJob만, 보조 분류는 enum(AspectLock/ConversionState/ConversionError)
- 모든 좌표·크기 산출은 짝수 픽셀 + 최소 크기 보장

## Dependencies

### Internal
- 없음 (의존 최소 계층)

### External
- Foundation, CoreGraphics, AppKit (NSImage)

<!-- MANUAL: -->
