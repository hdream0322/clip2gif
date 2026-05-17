import SwiftUI

struct TrimSlider: View {
    @Binding var startTime: TimeInterval
    @Binding var endTime: TimeInterval
    let duration: TimeInterval
    /// 핸들을 드래그할 때 호출. 어느 쪽 핸들이든 마지막 위치 시간을 넘김.
    var onScrub: ((TimeInterval) -> Void)? = nil

    private let handleSize: CGFloat = 18
    private let trackHeight: CGFloat = 6
    private let snap: TimeInterval = 0.1

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

            HStack {
                Text(formatTime(startTime))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("구간: \(formatTime(endTime - startTime))")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(endTime))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
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
