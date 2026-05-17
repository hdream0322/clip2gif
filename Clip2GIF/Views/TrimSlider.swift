import SwiftUI

struct TrimSlider: View {
    @Binding var startTime: TimeInterval
    @Binding var endTime: TimeInterval
    let duration: TimeInterval
    /// 핸들을 드래그할 때 호출. 어느 쪽 핸들이든 마지막 위치 시간을 넘김.
    var onScrub: ((TimeInterval) -> Void)? = nil
    /// "현재 프리뷰 위치"를 반환 (시작/끝 지정 버튼용). nil 이면 버튼 숨김.
    var playheadSeconds: (() -> TimeInterval)? = nil

    private let handleSize: CGFloat = 18
    private let trackHeight: CGFloat = 6
    private let snap: TimeInterval = 0.1
    private let fineStep: TimeInterval = 0.1

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                // 레이아웃 초기/극소 폭에서 trackWidth 가 0 이하가 되면
                // ratio 계산이 NaN/Inf → 핸들이 사라진다. 최소 1로 가드.
                let trackWidth = max(1, geo.size.width - handleSize)
                let safeDuration = max(duration, 0.0001)
                let startX = CGFloat(startTime / safeDuration) * trackWidth + handleSize / 2
                let endX = CGFloat(endTime / safeDuration) * trackWidth + handleSize / 2

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: trackHeight)
                        .padding(.horizontal, handleSize / 2)

                    Rectangle()
                        .fill(Color.accentColor.opacity(0.4))
                        .frame(width: max(0, endX - startX), height: trackHeight)
                        .offset(x: startX)

                    handleView(systemName: "chevron.left")
                        .position(x: startX, y: geo.size.height / 2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let ratio = (value.location.x - handleSize / 2) / trackWidth
                                    let raw = Double(ratio) * safeDuration
                                    let snapped = (raw / snap).rounded() * snap
                                    let clamped = max(0, min(snapped, endTime - snap))
                                    startTime = clamped
                                    onScrub?(clamped)
                                }
                        )

                    handleView(systemName: "chevron.right")
                        .position(x: endX, y: geo.size.height / 2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let ratio = (value.location.x - handleSize / 2) / trackWidth
                                    let raw = Double(ratio) * safeDuration
                                    let snapped = (raw / snap).rounded() * snap
                                    let clamped = min(safeDuration, max(snapped, startTime + snap))
                                    endTime = clamped
                                    onScrub?(clamped)
                                }
                        )
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 30)

            HStack(spacing: 6) {
                endpointControl(
                    title: "시작",
                    time: startTime,
                    onMinus: { setStart(startTime - fineStep) },
                    onPlus: { setStart(startTime + fineStep) },
                    onPlayhead: playheadSeconds.map { ph in { setStart(ph()) } }
                )
                Spacer()
                Text("구간 \(formatTime(endTime - startTime))")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                endpointControl(
                    title: "끝",
                    time: endTime,
                    onMinus: { setEnd(endTime - fineStep) },
                    onPlus: { setEnd(endTime + fineStep) },
                    onPlayhead: playheadSeconds.map { ph in { setEnd(ph()) } }
                )
            }
        }
    }

    /// 끝점 1개에 대한 미세조정(±0.1s)·시간표시·"현재위치" 버튼 묶음.
    @ViewBuilder
    private func endpointControl(
        title: String,
        time: TimeInterval,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void,
        onPlayhead: (() -> Void)?
    ) -> some View {
        HStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Button(action: onMinus) { Image(systemName: "minus") }
                .buttonStyle(.borderless)
            Text(formatTime(time))
                .font(.callout.monospacedDigit())
                .frame(minWidth: 56)
            Button(action: onPlus) { Image(systemName: "plus") }
                .buttonStyle(.borderless)
            if let onPlayhead {
                Button(action: onPlayhead) { Image(systemName: "smallcircle.filled.circle") }
                    .buttonStyle(.borderless)
                    .help("현재 프리뷰 위치를 \(title)으로")
            }
        }
        .font(.caption)
    }

    /// 드래그와 동일한 스냅·경계 규칙으로 시작점 설정.
    private func setStart(_ value: TimeInterval) {
        let snapped = (value / snap).rounded() * snap
        let clamped = max(0, min(snapped, endTime - snap))
        startTime = clamped
        onScrub?(clamped)
    }

    private func setEnd(_ value: TimeInterval) {
        let safeDuration = max(duration, 0.0001)
        let snapped = (value / snap).rounded() * snap
        let clamped = min(safeDuration, max(snapped, startTime + snap))
        endTime = clamped
        onScrub?(clamped)
    }

    private func handleView(systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: handleSize, height: handleSize)
                .shadow(radius: 2)
            Image(systemName: systemName)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let f = Int((t.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", m, s, f)
    }
}
