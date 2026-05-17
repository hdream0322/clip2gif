<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-27 | Updated: 2026-05-17 -->

# scripts

## Purpose
개발 환경 부트스트랩·유틸리티 셸 스크립트.

## Key Files
| File | Description |
|------|-------------|
| `bootstrap.sh` | xcodegen·gifski 의존성 체크 → gifski 바이너리를 `VideoToGif/Resources/bin/`로 복사 → `xcodegen generate` 실행 |

## For AI Agents

### Working In This Directory
- 스크립트는 bash 기준, `set -e` 권장
- macOS Homebrew 가정 (`brew --prefix`로 gifski 위치 탐색)
- 새 스크립트 추가 시 `chmod +x` 잊지 말기

### Testing Requirements
- `bash -n script.sh`로 문법 검증
- 실제 환경에서 1회 실행 검증

### Common Patterns
- 의존성 누락 시 사용자 친화 한국어 메시지 + 설치 명령 안내

## Dependencies

### External
- bash, Homebrew (xcodegen, gifski)

<!-- MANUAL: -->
