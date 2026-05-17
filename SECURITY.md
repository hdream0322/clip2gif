# 보안 정책 및 운영 가이드

Clip2GIF은 개인용 macOS 앱이지만, **App Sandbox OFF · 코드서명/공증 비활성 ·
Sparkle 자동 업데이트**라는 조합 때문에 신뢰 경계가 좁아도 한 곳이 뚫리면
사용자 권한 전체의 임의 코드 실행으로 확대될 수 있다. 아래 운영 수칙을
지키는 것이 사실상 유일한 방어선이다.

## 1. Sparkle 서명키 (`SPARKLE_PRIVATE_KEY`) — 최우선 자산

자동 업데이트의 신뢰는 전적으로 EdDSA 개인키 하나에 묶여 있다. 이 키가
유출되거나 릴리스 파이프라인이 탈취되면, **서명이 유효한 악성 업데이트가
모든 사용자에게 자동 배포**된다(비샌드박스·미서명이라 추가 방어선 없음).

- **공개키**: `project.yml` 의 `SUPublicEDKey` (공개 노출 정상).
- **개인키**: GitHub Actions Secret `SPARKLE_PRIVATE_KEY` 로만 보관.
  리포지터리·git 히스토리·로컬 디스크에 절대 커밋하지 않는다.

### 필수 조치

1. **보호된 Environment 로 이동**: `SPARKLE_PRIVATE_KEY` 를 리포 레벨 Secret
   이 아니라 GitHub *Environment* (예: `release`) Secret 으로 옮기고,
   해당 Environment 에 **필수 리뷰어 / 브랜치 보호 규칙**을 건다. 릴리스
   워크플로만 그 Environment 를 참조하게 한다.
2. **오프라인 백업**: EdDSA 개인키를 오프라인(암호화된 외부 매체)에 백업.
   분실 시 기존 사용자에게 업데이트를 더 이상 전달할 수 없다.
3. **회전 절차 문서화**: 키 유출 의심 시
   - 새 키쌍 생성 (`generate_keys`),
   - `SUPublicEDKey` 교체 후 정식 릴리스,
   - 구키로 서명된 appcast 무효화(이전 릴리스 자산 삭제/교체),
   - 사용자에게 수동 재설치 공지.
4. **다운그레이드/채널 검증**: `SparkleUpdater.swift` 의 `updaterDelegate`
   를 두어 `feedURLString` 고정·시스템 프로파일 전송 차단 등 정책을
   코드로 강제하는 것을 권장(파이프라인 침해 시 2차 방어).

## 2. 번들 무결성

- `gifski` 바이너리는 실행 전 `GifskiEncoder.locate()` 에서 SHA-256 으로
  검증한다. 바이너리를 교체하면
  `shasum -a 256 Clip2GIF/Resources/bin/gifski` 로 해시를 재계산해
  `GifskiEncoder.expectedSHA256` 상수를 갱신해야 한다(미갱신 시 변환 불가).
- `ENABLE_HARDENED_RUNTIME` 활성화 권장(코드 인젝션·라이브러리 검증 강화,
  Process 실행과 양립). 변경 시 ad-hoc 서명과의 호환을 ⌘R 로 실제 검증.

## 3. 입력 처리

- 외부 진입점(드래그&드롭 / Finder 서비스 / Open With)은 확장자
  화이트리스트(`mp4/mov/m4v/avi/webm`)만 검증한다. 확장자는 콘텐츠를
  보장하지 않으며, 이후 파싱은 AVFoundation 의 견고성에 의존한다.
- gifski 는 `Process.arguments` 배열로 호출하므로 셸 인젝션은 없다.

## 취약점 보고

개인 프로젝트로 공식 보안팀은 없다. 이슈 트래커 또는
heodream0322@gmail.com 으로 제보.
