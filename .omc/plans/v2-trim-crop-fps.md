# v2: 트림 미리보기 + 크롭 + FPS 자유화

## 변경 요약
1. **트림 스크럽**: 트림 핸들 이동 시 해당 시점 프레임이 프리뷰에 즉시 갱신
2. **재생 버튼**: 트림 구간만 한 번 재생 (AVPlayerView)
3. **크롭**: 드래그 가능한 박스 오버레이 (리사이즈/이동), 결과 GIF는 크롭된 영역만
4. **FPS 자유화**: 5~30 사이 1단위 슬라이더
5. **출력 너비 제거**: 크롭이 크기 조절 역할 흡수

## Acceptance Criteria
- 트림 핸들을 드래그하면 200ms 이내 프리뷰 프레임이 갱신
- "▶ 미리보기 재생" 버튼 → 트림 시작점부터 끝점까지 재생 후 정지
- 크롭 박스: 모서리 4개 + 변 4개 핸들로 리사이즈, 박스 내부 드래그로 이동
- 크롭 박스는 비디오 영역 밖으로 못 나감 (clamp)
- "리셋" 버튼으로 크롭 박스 원본 전체로 복원
- FPS 슬라이더 5~30, 라벨로 현재 값 표시
- 변환 결과 GIF의 픽셀 크기 = 크롭 박스 크기
- 기존 변환 파이프라인 정상 동작

## Implementation Steps

### Models 수정
- `ConversionSettings.swift`
  - `width: Int?` 삭제
  - `cropRect: CGRect` 추가 (정규화 좌표 0~1, 기본 `CGRect(0,0,1,1)` = 전체)
  - FPS: 그대로 Int, 다만 검증 범위만 5...30
  - `effectivePixelRect(for naturalSize:) -> CGRect` 헬퍼 (정규화 → 픽셀)

### Services 수정
- `FrameExtractor.swift`
  - 프레임 추출 후 `CGImage.cropping(to: pixelRect)`로 크롭
  - PNG 저장 시 크롭된 이미지 저장
- `GifskiEncoder.swift`
  - `--width` 인자 제거 (크롭으로 이미 정해진 픽셀 크기)

### Views 수정
- `SettingsPanel.swift`
  - "출력 너비" Picker 제거
  - FPS Picker → Slider(5...30, step 1) + 라벨
- `TrimSlider.swift`
  - 핸들 드래그 콜백 추가: `onScrub: (TimeInterval) -> Void`
- 신규 `PreviewView.swift`
  - AVPlayer + AVPlayerView 래퍼 (NSViewRepresentable)
  - `@Binding var currentTime: TimeInterval`
  - `playRange(start, end)` 메소드
  - 재생 종료 시 정지 콜백
- 신규 `CropOverlayView.swift`
  - 비디오 프리뷰 위에 ZStack으로 얹는 SwiftUI 뷰
  - `@Binding var cropRect: CGRect` (정규화)
  - 4 모서리 핸들 + 박스 내부 드래그
  - clamp to 0~1
- `ContentView.swift`
  - 좌측: PreviewView + CropOverlayView (ZStack), 아래 TrimSlider + ▶ 버튼
  - 우측: SettingsPanel + 크롭 리셋 버튼 + ConvertButton
  - 트림 스크럽 → PreviewView.seek(to:)
  - 재생 버튼 → PreviewView.playRange(start, end)

## Risks
- AVPlayerView의 NSViewRepresentable 래핑에서 AVPlayer 라이프사이클 관리 주의 (메모리 누수)
- CropOverlayView 좌표계: 비디오 프리뷰의 실제 표시 영역 vs 정규화 좌표 변환 정확히
- FrameExtractor 크롭 시 CGImage.cropping은 픽셀 정수 좌표 필요 → 반올림

## Out of Scope
- 크롭 비율 잠금 (자유 비율만)
- 재생 시 사운드 (음소거)
- 다중 크롭 영역
