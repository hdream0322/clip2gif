# Clip2GIF

macOS용 동영상 → GIF 변환 앱입니다. 비디오 파일을 드래그하거나 불러온 뒤, 품질·속도·해상도를 설정하고 GIF로 내보낼 수 있습니다.

## 요구 사항

- macOS 13.0 이상
- Xcode 15 이상
- [Homebrew](https://brew.sh)

## 설정

```bash
# 의존성 설치
brew install xcodegen gifski

# 프로젝트 초기화 (gifski 복사 + .xcodeproj 생성)
./scripts/bootstrap.sh

# Xcode로 열기
open Clip2GIF.xcodeproj
```

## 지원 포맷

입력: mp4, mov, m4v, avi, webm
