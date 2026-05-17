# 서드파티 고지 (Third-Party Notices)

이 앱은 다음 서드파티 소프트웨어를 번들·재배포합니다.

## gifski

- **용도**: GIF 인코딩 (별도 CLI 프로세스로 실행)
- **번들 위치**: `Clip2GIF/Resources/bin/gifski`
- **버전**: 1.34.0
- **저작자**: Kornel Lesiński 외 ([ImageOptim/gifski](https://github.com/ImageOptim/gifski))
- **라이선스**: GNU Affero General Public License v3.0 only (`AGPL-3.0-only`)
- **라이선스 전문**: [`Clip2GIF/Resources/bin/gifski-LICENSE.txt`](Clip2GIF/Resources/bin/gifski-LICENSE.txt)

### 대응 소스 코드 (Corresponding Source)

AGPL-3.0에 따라, 번들된 gifski 바이너리에 정확히 대응하는 소스 코드는
아래에서 입수할 수 있습니다.

- 릴리스 태그: <https://github.com/ImageOptim/gifski/releases/tag/1.34.0>
- 소스 트리: <https://github.com/ImageOptim/gifski/tree/1.34.0>
- crates.io: `cargo install gifski@1.34.0` (<https://crates.io/crates/gifski/1.34.0>)

위 소스는 본 저장소 운영자의 변경 없이 업스트림 원본 그대로이며,
빌드 방법은 gifski 저장소의 `README.md`("Building" 절)를 따릅니다.

gifski는 저작자가 별도의 **상업용 라이선스**도 제공합니다.
AGPL-3.0와 호환되지 않는 용도로 사용하려면 저작자에게 문의하세요:
<https://kornel.ski/contact> / <https://supso.org/projects/pngquant>

### 본 앱과의 관계

이 앱은 gifski를 라이브러리로 정적·동적 링크하지 않고, 번들된 실행 파일을
**별도 프로세스로 호출(exec)** 하여 사용합니다. 따라서 gifski의 AGPL-3.0
의무는 재배포되는 gifski 바이너리 및 그 대응 소스에 한해 적용됩니다.
