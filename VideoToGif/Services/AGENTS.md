<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-27 | Updated: 2026-05-17 -->

# Services

## Purpose
비즈니스 로직. 비디오 로딩, 프레임 추출, GIF 인코딩, 용량 추정(정적/실측 2종), 도크 진행률. 모두 정적 함수 또는 enum 네임스페이스.

## Key Files
| File | Description |
|------|-------------|
| `VideoLoader.swift` | AVURLAsset로 메타·썸네일 추출. preferredTransform 반영 naturalSize + nominalFrameRate(기본 30). async load(url:) → VideoSource |
| `FrameExtractor.swift` | `AVAssetImageGenerator.copyCGImage` **직렬 동기** 호출 + autoreleasepool로 메모리 폭주 방지. 정적 헬퍼 `applyCrop`(픽셀 크롭·교차) / `toneMappedSDR`(HDR HLG/PQ → sRGB, macOS14 toneMapHDRtoSDR / 13 색공간변환) / `writePNG`(CGImageDestination). 샘플링 시점 = `start + (i/fps)*speed` |
| `GifskiEncoder.swift` | 번들 gifski locate + 실행권한 자동 부여. Process 비동기 실행. 인자: `--fps`/`--quality`/`--repeat`(0 무한·-1 1회)/`--bounce`/축소 시 `--width`. stderr `Frame N / M` 파싱, 없으면 0.9 점근 합성 진행률 ticker |
| `PreflightEstimator.swift` | 짧은 프리플라이트 인코딩으로 실제 GIF 용량 ±10% 예측. ≤16프레임이면 전체 인코딩, 아니면 작은(4)·큰(12) 윈도우 동시 인코딩 → 2점 선형회귀(perFrame/baseline) 외삽 |
| `OutputEstimator.swift` | 인코딩 없는 정적 용량 추정(프리플라이트 전 폴백). low/high 범위(정적 ~30%, 동적 100%). `formattedRoundedMB`(gifski식 MB/KB 반올림 "약 N MB") |
| `DockProgress.swift` | @MainActor enum. 도크 아이콘 둘레 진행률 링을 NSView 타일로 그림. `set(_:)` nil/0/1이면 해제 |

## For AI Agents

### Working In This Directory
- **메모리 주의**: 프레임 추출은 직렬 + autoreleasepool 필수. `generateCGImagesAsynchronously` 일괄 사용 금지 (3000px 영상에서 13GB+ 폭주 사례)
- PreflightEstimator는 FrameExtractor의 `applyCrop`/`toneMappedSDR`/`writePNG`를 재사용 — 시그니처 변경 시 동시 점검
- gifski locate 실패 = `binaryMissing` throw. 경로는 `Bundle.main.url(forResource: "gifski", withExtension: nil)` (subdirectory 없음)
- gifski는 비-TTY에서 진행 로그를 안 내보낼 수 있음 → 합성 진행률 ticker가 필수 (제거 금지)
- `bounce`는 gifski 네이티브 `--bounce` 플래그로만 처리 (프레임 역순 수동 첨부 시 gifski가 파일명 재정렬 → 절반 속도 버그)
- 진행률 콜백은 메인 스레드 디스패치 필수 (UI/DockProgress 직결)
- OutputEstimator는 q=100에서 0.033 byte/pixel-frame 상한(실측 기반). PreflightEstimator가 실패할 때만 노출되는 폴백

### Testing Requirements
- 큰 영상(1080p+) 변환 시 메모리 모니터링
- gifski 종료 코드 != 0 케이스 (잘못된 PNG, 디스크 풀) → `gifskiCrashed` stderr 노출 확인
- 프리플라이트 추정 vs 실제 차이 ±10% 이내 — 자주 이탈하면 윈도우 크기/회귀식 재조정
- HDR(HLG/PQ) 영상 1개로 색 물빠짐 없는지 확인

### Common Patterns
- 모든 함수 async/throws, Process 작업은 `withCheckedThrowingContinuation` wrapping
- 추출 루프는 `Result` + autoreleasepool per-frame
- ConversionError 변형으로 실패 표면화

## Dependencies

### Internal
- `Models/`: VideoSource, ConversionSettings, ConversionError 사용

### External
- AVFoundation, AppKit, CoreImage, ImageIO, CoreGraphics, UniformTypeIdentifiers, Foundation
- 외부 바이너리: gifski (번들됨)

<!-- MANUAL: -->
