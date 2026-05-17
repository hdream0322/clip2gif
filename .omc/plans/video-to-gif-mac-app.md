# Video → GIF 변환 macOS 앱 (개인용)

## Requirements Summary
- **플랫폼**: macOS 13+ (SwiftUI), Apple Silicon + Intel
- **언어/툴**: Swift 5.9+, SwiftUI, Xcode 15+
- **변환 엔진**: Gifski (Rust 바이너리) + AVFoundation (프레임 추출)
- **기능 범위**: MVP + 기본 편집 (트림, FPS, 사이즈, 품질, 프리뷰)
- **배포**: 개인용 로컬 실행, 코드 서명/notarization 생략
- **저장소 구조**: 단일 Xcode 프로젝트 `VideoToGif.xcodeproj`

## Acceptance Criteria
1. 앱 아이콘 더블클릭 → 메인 윈도우 1초 이내 표시
2. mp4/mov/m4v/avi/webm 5종 포맷을 드래그&드롭으로 받을 것
3. 비디오 로드 시 썸네일 + 길이(초) + 해상도 표시
4. 트림 슬라이더(시작/끝)로 구간 선택 가능, 미리보기 프레임 갱신
5. FPS(10/15/20/24/30), 너비(원본/640/480/320), 품질(1~100) 조절
6. "변환" 버튼 → 진행률 ProgressView, 완료 시 Finder에서 결과물 위치 노출
7. 1분짜리 1080p mp4 → 480px·15fps·품질80 GIF 변환을 90초 이내에 완료 (M1 기준)
8. 변환 실패 시 에러 토스트로 원인 표시 (파일 손상, 디스크 공간, 엔진 크래시)
9. 앱 종료 후 재실행 시 마지막 출력 폴더 기억

## Implementation Steps

### Step 1: Xcode 프로젝트 생성
- Xcode → New Project → macOS → App → SwiftUI / Swift / No Tests
- Bundle ID: `com.heodream.VideoToGif`
- 최소 배포 타겟: macOS 13.0
- 산출물: `VideoToGif.xcodeproj`, `VideoToGifApp.swift`, `ContentView.swift`

### Step 2: 외부 바이너리 번들링
- Gifski 바이너리: `brew install gifski` 후 `which gifski`로 경로 확인
- 프로젝트에 `Resources/bin/gifski` 복사 → "Copy Bundle Resources" 빌드 단계에 추가
- 실행 권한 유지 위해 빌드 페이즈에 `chmod +x` 스크립트 단계 1개 추가
- Bundle.main.url(forResource:"gifski", withExtension:nil) 로 런타임에 접근

### Step 3: 데이터 모델
- `VideoSource.swift`: URL, duration(TimeInterval), naturalSize(CGSize), thumbnail(NSImage)
- `ConversionSettings.swift`: trimStart, trimEnd, fps:Int, width:Int?, quality:Int (1...100)
- `ConversionJob.swift`: enum 상태 (idle, extracting, encoding, done(URL), failed(Error)) + progress(Double)

### Step 4: 비디오 로딩 / 메타 추출
- `VideoLoader.swift` — AVAsset.load(.duration, .tracks)
- 썸네일: AVAssetImageGenerator로 0초 시점 1장
- 드롭 영역: `.onDrop(of: [.movie, .fileURL]) { ... }` ContentView 루트에 부착

### Step 5: 프레임 추출 파이프라인
- `FrameExtractor.swift` — AVAssetImageGenerator.generateCGImagesAsynchronously
- 트림 구간을 fps로 샘플링 → CMTime 배열 생성
- 추출된 CGImage를 임시 디렉토리(`FileManager.default.temporaryDirectory/job-{uuid}/frame_%05d.png`)에 PNG로 저장
- 진행률을 콜백으로 전달 (extracted/total)

### Step 6: Gifski 호출
- `GifskiEncoder.swift` — Process 사용
- 인자: `--fps {fps} --width {width} --quality {quality} -o {output.gif} {tmpDir}/frame_*.png`
- stderr 파싱으로 진행률 업데이트 (gifski는 `Frame N/M` 형식 출력)
- 완료 후 임시 프레임 디렉토리 삭제

### Step 7: SwiftUI UI
- `ContentView.swift`: 좌측 비디오 프리뷰 + 트림 슬라이더, 우측 설정 패널
- `TrimSlider.swift`: 듀얼 핸들 슬라이더 (TimelineView 또는 커스텀 GeometryReader)
- `SettingsPanel.swift`: FPS Picker, Width Picker, Quality Slider
- `ConvertButton.swift`: 상태에 따라 라벨/색상 변경, ProgressView 인라인 표시

### Step 8: 출력 처리
- 기본 출력 경로: 입력 파일과 같은 폴더 + `_converted.gif` 접미사
- 사용자 지정 출력 폴더는 NSSavePanel 또는 `.fileImporter`
- 완료 시 NSWorkspace.shared.activateFileViewerSelecting(url) 로 Finder 노출
- AppStorage("lastOutputDir") 로 마지막 폴더 기억

### Step 9: 에러 처리
- ConversionError 열거형 (ioFailed, gifskiCrashed(code:Int32), unsupportedCodec, cancelled)
- ContentView에 `.alert(item:)` 바인딩으로 노출
- gifski Process 종료 코드 ≠ 0 → stderr 마지막 5줄 첨부

### Step 10: 빌드 & 실행 확인
- Cmd+R 로 디버그 실행, 샘플 mp4 5개로 변환 검증
- Release 빌드 → `.app` 산출물을 `~/Applications/`에 복사하여 일상 사용
- 코드 서명 없이도 본인 머신에선 정상 실행됨 (Gatekeeper 우회 불필요)

## File Layout
```
VideoToGif/
├── VideoToGif.xcodeproj
├── VideoToGif/
│   ├── VideoToGifApp.swift
│   ├── ContentView.swift
│   ├── Models/
│   │   ├── VideoSource.swift
│   │   ├── ConversionSettings.swift
│   │   └── ConversionJob.swift
│   ├── Services/
│   │   ├── VideoLoader.swift
│   │   ├── FrameExtractor.swift
│   │   └── GifskiEncoder.swift
│   ├── Views/
│   │   ├── DropZoneView.swift
│   │   ├── TrimSlider.swift
│   │   ├── SettingsPanel.swift
│   │   └── ConvertButton.swift
│   └── Resources/
│       ├── bin/gifski
│       └── Assets.xcassets
```

## Risks and Mitigations
| 위험 | 영향 | 완화책 |
|---|---|---|
| Gifski 바이너리 아키텍처 (Intel/ARM) 불일치 | 실행 실패 | universal binary 사용 또는 Apple Silicon만 지원 명시 |
| 큰 비디오 메모리 사용 | 앱 크래시 | 프레임을 PNG로 디스크에 쓰고 일괄 인코딩 (메모리 캐시 X) |
| Process가 sandbox에서 외부 바이너리 실행 거부 | 변환 실패 | 개인용이므로 sandbox 비활성화 (Capabilities) |
| AVAssetImageGenerator가 일부 코덱 미지원 | 추출 실패 | "지원되지 않는 코덱입니다" 에러 분기 |
| 임시 디렉토리 누적 | 디스크 낭비 | defer로 작업 완료/실패 모두에서 정리, 시작 시 1회 청소 |

## Verification Steps
1. **빌드**: `xcodebuild -project VideoToGif.xcodeproj -scheme VideoToGif build` 성공
2. **드롭 테스트**: mp4/mov 각 1개를 드래그 → 메타데이터 정상 표시
3. **변환 테스트**: 5초/30초/60초 비디오 각각 변환 → GIF 파일 생성 확인
4. **에러 테스트**: 깨진 mp4 / 권한 없는 출력 폴더 → 알림 노출
5. **장시간 사용**: 10회 연속 변환 후 메모리 누수 없는지 Instruments(Allocations) 확인
6. **성능 기준**: AC #7 충족 여부 측정

## Out of Scope (V1)
- 자막 / 캡션 / 워터마크 / 필터
- 일괄 변환, 드래그 다중 파일
- 파레트 커스터마이징
- 코드 서명 / notarization / App Store 제출
- 자동 업데이트
