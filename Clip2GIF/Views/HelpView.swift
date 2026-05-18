import SwiftUI

/// 메뉴바 "도움말 > Clip2GIF 도움말"로 열리는 별도 창.
/// 좌측 사이드바에서 주제를 고르면 우측에 상세 내용이 표시된다.
struct HelpView: View {
    private enum Topic: String, CaseIterable, Identifiable {
        case basics = "기본 사용법"
        case features = "기능별 상세 설명"
        case shortcuts = "단축키"
        case faq = "문제 해결 / FAQ"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .basics:    return "play.circle"
            case .features:  return "slider.horizontal.3"
            case .shortcuts: return "keyboard"
            case .faq:       return "questionmark.circle"
            }
        }
    }

    @State private var selection: Topic = .basics

    var body: some View {
        HStack(spacing: 0) {
            List(Topic.allCases, selection: $selection) { topic in
                Label(topic.rawValue, systemImage: topic.icon)
                    .tag(topic)
            }
            .listStyle(.sidebar)
            .frame(width: 200)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch selection {
                    case .basics:    basics
                    case .features:  features
                    case .shortcuts: shortcuts
                    case .faq:       faq
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    // MARK: - 기본 사용법

    @ViewBuilder
    private var basics: some View {
        title("기본 사용법")
        lead("영상을 불러와 구간·크기를 정한 뒤 GIF로 변환합니다. 네 단계면 끝납니다.")

        step(1, "영상 불러오기",
             "창에 영상 파일을 드래그&드롭하거나, \(kbd("⌘O"))로 파일을 선택합니다. " +
             "Finder에서 영상을 우클릭해 ‘서비스’ 또는 ‘다음으로 열기 > Clip2GIF’로도 열 수 있습니다. " +
             "여러 파일을 한 번에 선택·드롭하면 같은 설정으로 일괄(배치) 변환합니다.")
        step(2, "구간 정하기",
             "프리뷰 아래 트림 막대의 양 끝 핸들을 끌어 시작·끝을 정합니다. " +
             "‘시작/끝’의 \(kbd("−"))\(kbd("+")) 버튼으로 0.1초씩 미세 조정하거나, 재생 위치에서 ‘현재’ 버튼으로 그 지점을 끝점으로 지정할 수 있습니다.")
        step(3, "크기·화질 설정",
             "프리뷰 위 사각형(크롭 박스)을 끌어 원하는 영역만 잘라냅니다. " +
             "오른쪽 패널에서 프레임율·재생 속도·출력 배율·화질을 조정합니다. ‘예상 결과’에 최종 용량이 ±10%로 미리 표시됩니다.")
        step(4, "변환",
             "\(kbd("Return")) 또는 ‘GIF로 변환’ 버튼을 누릅니다. 완료되면 결과 미리보기 창이 자동으로 열립니다. " +
             "GIF는 기본적으로 원본 영상과 같은 폴더에 \(code("_converted.gif"))로 저장됩니다(‘저장 위치 > 변경’으로 폴더 지정 가능).")

        note("지원 형식: \(SupportedVideo.displayList). 그 외 형식은 불러올 때 안내가 표시됩니다.")
    }

    // MARK: - 기능별 상세 설명

    @ViewBuilder
    private var features: some View {
        title("기능별 상세 설명")

        section("트림 (구간 자르기)")
        bullet("양 끝 핸들 드래그로 시작·끝 지정. 0.1초 단위로 스냅됩니다.")
        bullet("‘시작/끝’의 \(kbd("−"))\(kbd("+"))는 0.1초씩 미세 조정. 한계(시작 0초·끝=영상 끝)에 닿으면 해당 버튼이 비활성화됩니다.")
        bullet("‘현재’ 버튼: 프리뷰의 현재 재생 위치를 시작 또는 끝 지점으로 즉시 지정.")

        section("크롭 (영역 잘라내기)")
        bullet("프리뷰 위 사각형 박스를 끌거나 모서리를 드래그해 출력 영역을 지정합니다.")
        bullet("‘비율’ 메뉴로 1:1·16:9·9:16 등 자주 쓰는 비율로 박스를 고정할 수 있습니다.")
        bullet("‘크롭 리셋’으로 전체 프레임·자유 비율로 되돌립니다.")

        section("재생 설정")
        bullet("프레임율: 5fps ~ 원본 프레임율. 낮출수록 파일이 가벼워지고 움직임이 거칠어집니다.")
        bullet("재생 속도: 0.5x ~ 10x. 0.5/1/2/4x 빠른 버튼 제공. 속도를 올리면 출력 길이·프레임 수가 줄어듭니다.")
        bullet("무한 반복: GIF가 끝없이 반복 재생됩니다(끄면 1회만 재생). 파일 크기에는 영향 없습니다.")
        bullet("왕복(Bounce): 끝에 도달하면 역재생으로 처음까지 돌아옵니다. 프레임이 약 2배가 되어 용량도 커집니다.")

        section("출력 크기")
        bullet("100 / 75 / 50 / 25% 배율. 가로·세로 비율은 항상 유지됩니다.")
        bullet("배율을 줄이면 픽셀 수가 줄어 파일이 크게 가벼워집니다. 각 배율의 실제 픽셀 크기가 함께 표시됩니다.")

        section("화질")
        bullet("프리셋: 원본(100) / 높음(85, 일반 권장) / 보통(70, SNS용) / 낮음(50) / 사용자 지정.")
        bullet("높일수록 색과 디테일을 더 보존해 또렷하지만 파일이 커집니다.")
        bullet("‘고급 압축’: 모션 품질(프레임 간·시간 압축)과 손실 품질(프레임 내·공간 압축)을 개별 조정. 기본은 gifski 자동값입니다.")

        section("예상 결과 / 용량 추정")
        bullet("설정을 바꾸면 실제 gifski로 작은·큰 구간을 시험 인코딩해 최종 용량을 ±10%로 추정합니다(약 0.6초 후).")
        bullet("추정 진행 중에는 즉시 폴백 범위가 먼저 표시되고, 완료되면 정확값으로 갱신됩니다.")

        section("결과 / 원본 파일 관리")
        bullet("변환 완료 시 결과 미리보기 창이 자동으로 열립니다. 거기서 Finder 표시·기본 앱으로 열기·GIF 복사 가능.")
        bullet("원본 영상은 ‘Finder에서 보기 · 복사 · 휴지통 · 파일 변경’ 버튼으로 관리합니다.")
        bullet("같은 이름의 GIF가 있으면 \(code("_2")), \(code("_3")) … 을 붙여 기존 결과를 덮어쓰지 않습니다.")

        section("배치 변환")
        bullet("여러 영상을 한 번에 선택·드롭하면 현재 화질·속도·배율·반복·왕복 설정으로 순차 변환합니다.")
        bullet("배치에서는 크롭·트림이 적용되지 않고 전체 프레임·전체 길이로 변환됩니다.")
    }

    // MARK: - 단축키

    @ViewBuilder
    private var shortcuts: some View {
        title("단축키")
        lead("자주 쓰는 키보드 단축키입니다.")

        shortcutRow("⌘O", "영상 파일 열기 (여러 개 선택 시 배치 변환)")
        shortcutRow("Space", "프리뷰 재생 / 일시정지")
        shortcutRow("Return", "GIF로 변환 시작")
        shortcutRow("⌘.", "변환 취소 (변환 중에만)")
        shortcutRow("Esc", "결과 미리보기 창 닫기")

        note("크롭 박스·트림 핸들은 마우스로 직접 끌어 조정합니다. 트림 미세 조정은 ‘시작/끝’의 −/+ 버튼을 사용하세요.")
    }

    // MARK: - 문제 해결 / FAQ

    @ViewBuilder
    private var faq: some View {
        title("문제 해결 / FAQ")

        qa("‘저장 공간이 부족합니다’ 오류가 나요",
           "변환 중 프레임을 임시 폴더에 PNG로 저장합니다. 필요한 임시 용량(메시지에 표시됨)만큼 디스크를 비운 뒤 다시 시도하세요. " +
           "출력 배율을 낮추거나 트림 구간을 줄이면 필요한 공간도 줄어듭니다.")

        qa("‘원본 영상을 찾을 수 없습니다’ 라고 나와요",
           "변환 도중 원본 파일이 이동·삭제·이름변경되면 발생합니다. 원본을 그대로 두고 변환이 끝날 때까지 기다리세요.")

        qa("‘프레임이 너무 많습니다’ 라고 나와요",
           "트림 구간을 줄이거나, 프레임율(FPS)을 낮추거나, 재생 속도를 올려 전체 프레임 수를 줄이세요.")

        qa("GIF 파일이 너무 커요",
           "출력 배율을 낮추는 것이 가장 효과적입니다. 그다음 화질 프리셋을 ‘보통/낮음’으로, 프레임율을 낮추고, 왕복(Bounce)을 끄세요. " +
           "‘예상 결과’를 보며 설정을 조절하면 됩니다.")

        qa("변환이 너무 느리거나 메모리를 많이 써요",
           "고해상도·장시간 영상은 프레임 수가 많아 시간이 걸립니다. 출력 배율·트림 구간을 줄이면 빨라집니다. " +
           "프레임은 메모리 폭주를 막기 위해 한 장씩 순차 처리하도록 설계되어 있습니다.")

        qa("왕복(Bounce)을 켰더니 용량이 두 배가 됐어요",
           "정상입니다. 왕복은 정방향 + 역방향 프레임을 모두 포함하므로 프레임 수와 용량이 약 2배가 됩니다.")

        qa("결과 미리보기 창에 ‘파일 없음’이 떠요",
           "미리보기를 여는 사이에 GIF가 이동·삭제·이름변경된 경우입니다. 다시 변환하면 됩니다.")

        qa("지원하지 않는 형식이라고 나와요",
           "지원 형식은 \(SupportedVideo.displayList) 입니다. 다른 형식은 먼저 이 중 하나로 변환한 뒤 사용하세요.")

        qa("앱 업데이트는 어떻게 하나요",
           "메뉴바 ‘Clip2GIF > Check for Updates…’로 직접 확인할 수 있고, 새 버전이 나오면 자동으로 알림이 표시됩니다.")
    }

    // MARK: - 빌딩 블록

    private func title(_ t: String) -> some View {
        Text(t).font(.largeTitle.bold())
    }

    private func lead(_ t: String) -> some View {
        Text(t).font(.title3).foregroundStyle(.secondary)
    }

    private func section(_ t: String) -> some View {
        Text(t)
            .font(.title2.bold())
            .padding(.top, 6)
    }

    private func step(_ n: Int, _ heading: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.headline.monospacedDigit())
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.15), in: Circle())
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(heading).font(.headline)
                Text(body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func bullet(_ t: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").foregroundStyle(.secondary)
            Text(t).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shortcutRow(_ key: String, _ desc: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(key)
                .font(.body.monospaced().bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
                .frame(width: 90, alignment: .leading)
            Text(desc).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func qa(_ q: String, _ a: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Q. \(q)").font(.headline)
            Text(a).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private func note(_ t: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
            Text(t).fixedSize(horizontal: false, vertical: true)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .padding(.top, 6)
    }

    /// 본문 안에서 키 캡슐처럼 보이도록 감싸는 문자열 헬퍼.
    private func kbd(_ s: String) -> String { "［\(s)］" }
    private func code(_ s: String) -> String { "‘\(s)’" }
}
