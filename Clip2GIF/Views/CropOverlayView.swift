import SwiftUI

/// 비디오 프리뷰 위에 얹는 크롭 박스 오버레이.
/// cropRect는 정규화 좌표(0~1).
struct CropOverlayView: View {
    @Binding var cropRect: CGRect
    /// 유지할 정규화 좌표 기준 가로/세로 비율(width/height). nil 이면 자유 변형.
    var aspectRatio: CGFloat? = nil

    private let handleSize: CGFloat = 12
    private let edgeThickness: CGFloat = 14   // 변 핸들 hit area
    private let minSize: CGFloat = 0.05       // 최소 5% 크기

    /// 이동 제스처 시작 시점의 박스 원점(정규화). 드래그 동안 고정 기준점.
    @State private var moveStartOrigin: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let box = CGRect(
                x: cropRect.minX * w,
                y: cropRect.minY * h,
                width: cropRect.width * w,
                height: cropRect.height * h
            )

            ZStack(alignment: .topLeading) {
                // 외곽 어두움 - topLeading 정렬로 고정
                dimOverlay(canvasSize: geo.size, hole: box)

                // 크롭 박스 테두리(이동 핸들)
                Rectangle()
                    .stroke(Color.white, lineWidth: 1.5)
                    .frame(width: box.width, height: box.height)
                    .contentShape(Rectangle().inset(by: 4))
                    .offset(x: box.minX, y: box.minY)
                    .gesture(moveGesture(canvas: geo.size))

                // 변 핸들 (4개) - 한 축 리사이즈
                edgeHandle(side: .top, box: box, canvas: geo.size)
                edgeHandle(side: .bottom, box: box, canvas: geo.size)
                edgeHandle(side: .leading, box: box, canvas: geo.size)
                edgeHandle(side: .trailing, box: box, canvas: geo.size)

                // 모서리 핸들 (4개) - 양 축 리사이즈
                cornerHandle(at: .topLeading, box: box, canvas: geo.size)
                cornerHandle(at: .topTrailing, box: box, canvas: geo.size)
                cornerHandle(at: .bottomLeading, box: box, canvas: geo.size)
                cornerHandle(at: .bottomTrailing, box: box, canvas: geo.size)
            }
        }
    }

    // MARK: - Dim overlay (4면)

    @ViewBuilder
    private func dimOverlay(canvasSize: CGSize, hole: CGRect) -> some View {
        let dimColor = Color.black.opacity(0.45)
        ZStack(alignment: .topLeading) {
            // 위
            dimColor
                .frame(width: canvasSize.width, height: max(0, hole.minY))
            // 아래
            dimColor
                .frame(width: canvasSize.width, height: max(0, canvasSize.height - hole.maxY))
                .offset(x: 0, y: hole.maxY)
            // 좌
            dimColor
                .frame(width: max(0, hole.minX), height: hole.height)
                .offset(x: 0, y: hole.minY)
            // 우
            dimColor
                .frame(width: max(0, canvasSize.width - hole.maxX), height: hole.height)
                .offset(x: hole.maxX, y: hole.minY)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 이동

    private func moveGesture(canvas: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                // 드래그 시작 원점을 고정하고, 누적 translation을 그 기준에서
                // 한 번만 적용 → 마우스 이동과 1:1 매핑(가속 방지).
                let start = moveStartOrigin ?? cropRect.origin
                if moveStartOrigin == nil { moveStartOrigin = start }
                let dx = value.translation.width / canvas.width
                let dy = value.translation.height / canvas.height
                var newOrigin = start
                newOrigin.x = clamp(start.x + dx, 0, 1 - cropRect.width)
                newOrigin.y = clamp(start.y + dy, 0, 1 - cropRect.height)
                cropRect.origin = newOrigin
            }
            .onEnded { _ in
                moveStartOrigin = nil
            }
    }

    // MARK: - 변 핸들

    private enum Side { case top, bottom, leading, trailing }

    @ViewBuilder
    private func edgeHandle(side: Side, box: CGRect, canvas: CGSize) -> some View {
        let frame: CGRect = {
            switch side {
            case .top:
                return CGRect(x: box.minX, y: box.minY - edgeThickness/2,
                              width: box.width, height: edgeThickness)
            case .bottom:
                return CGRect(x: box.minX, y: box.maxY - edgeThickness/2,
                              width: box.width, height: edgeThickness)
            case .leading:
                return CGRect(x: box.minX - edgeThickness/2, y: box.minY,
                              width: edgeThickness, height: box.height)
            case .trailing:
                return CGRect(x: box.maxX - edgeThickness/2, y: box.minY,
                              width: edgeThickness, height: box.height)
            }
        }()
        let cursor: NSCursor = (side == .top || side == .bottom) ? .resizeUpDown : .resizeLeftRight

        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
            .onHover { hovering in
                if hovering { cursor.push() } else { NSCursor.pop() }
            }
            .gesture(edgeResizeGesture(side: side, canvas: canvas))
    }

    private func edgeResizeGesture(side: Side, canvas: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let nx = clamp(value.location.x / canvas.width, 0, 1)
                let ny = clamp(value.location.y / canvas.height, 0, 1)
                let r = cropRect

                if let ratio = aspectRatio {
                    cropRect = conformEdge(side: side, pointerX: nx, pointerY: ny,
                                           current: r, ratio: ratio)
                    return
                }

                var out = r
                switch side {
                case .top:
                    let newY = min(ny, r.maxY - minSize)
                    out = CGRect(x: r.minX, y: newY, width: r.width, height: r.maxY - newY)
                case .bottom:
                    let newMaxY = max(ny, r.minY + minSize)
                    out = CGRect(x: r.minX, y: r.minY, width: r.width, height: newMaxY - r.minY)
                case .leading:
                    let newX = min(nx, r.maxX - minSize)
                    out = CGRect(x: newX, y: r.minY, width: r.maxX - newX, height: r.height)
                case .trailing:
                    let newMaxX = max(nx, r.minX + minSize)
                    out = CGRect(x: r.minX, y: r.minY, width: newMaxX - r.minX, height: r.height)
                }
                cropRect = out
            }
    }

    // MARK: - 모서리 핸들

    private enum Corner { case topLeading, topTrailing, bottomLeading, bottomTrailing }

    private func cornerPosition(_ corner: Corner, box: CGRect) -> CGPoint {
        switch corner {
        case .topLeading: return CGPoint(x: box.minX, y: box.minY)
        case .topTrailing: return CGPoint(x: box.maxX, y: box.minY)
        case .bottomLeading: return CGPoint(x: box.minX, y: box.maxY)
        case .bottomTrailing: return CGPoint(x: box.maxX, y: box.maxY)
        }
    }

    private func cornerHandle(at corner: Corner, box: CGRect, canvas: CGSize) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1))
            .position(cornerPosition(corner, box: box))
            .gesture(cornerResizeGesture(corner: corner, canvas: canvas))
    }

    private func cornerResizeGesture(corner: Corner, canvas: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let nx = clamp(value.location.x / canvas.width, 0, 1)
                let ny = clamp(value.location.y / canvas.height, 0, 1)
                let r = cropRect

                if let ratio = aspectRatio {
                    // 드래그 반대편 모서리를 고정점으로 두고 비율을 유지.
                    let anchorX: CGFloat
                    let anchorY: CGFloat
                    let growLeft: Bool
                    let growUp: Bool
                    switch corner {
                    case .topLeading:     anchorX = r.maxX; anchorY = r.maxY; growLeft = true;  growUp = true
                    case .topTrailing:    anchorX = r.minX; anchorY = r.maxY; growLeft = false; growUp = true
                    case .bottomLeading:  anchorX = r.maxX; anchorY = r.minY; growLeft = true;  growUp = false
                    case .bottomTrailing: anchorX = r.minX; anchorY = r.minY; growLeft = false; growUp = false
                    }
                    cropRect = conformCorner(
                        anchorX: anchorX, anchorY: anchorY,
                        growLeft: growLeft, growUp: growUp,
                        desiredW: abs(nx - anchorX), desiredH: abs(ny - anchorY),
                        ratio: ratio
                    )
                    return
                }

                var out = r
                switch corner {
                case .topLeading:
                    let newX = min(nx, r.maxX - minSize)
                    let newY = min(ny, r.maxY - minSize)
                    out = CGRect(x: newX, y: newY, width: r.maxX - newX, height: r.maxY - newY)
                case .topTrailing:
                    let newMaxX = max(nx, r.minX + minSize)
                    let newY = min(ny, r.maxY - minSize)
                    out = CGRect(x: r.minX, y: newY, width: newMaxX - r.minX, height: r.maxY - newY)
                case .bottomLeading:
                    let newX = min(nx, r.maxX - minSize)
                    let newMaxY = max(ny, r.minY + minSize)
                    out = CGRect(x: newX, y: r.minY, width: r.maxX - newX, height: newMaxY - r.minY)
                case .bottomTrailing:
                    let newMaxX = max(nx, r.minX + minSize)
                    let newMaxY = max(ny, r.minY + minSize)
                    out = CGRect(x: r.minX, y: r.minY, width: newMaxX - r.minX, height: newMaxY - r.minY)
                }
                cropRect = out
            }
    }

    // MARK: - 비율 유지 헬퍼

    /// 고정 모서리(anchor) 기준으로 ratio(=w/h)를 유지하며 박스를 만든다.
    /// desiredW/H 는 자유 드래그 시의 폭/높이. 더 제약되는 축을 따라가 자연스럽게 동작.
    private func conformCorner(anchorX: CGFloat, anchorY: CGFloat,
                               growLeft: Bool, growUp: Bool,
                               desiredW: CGFloat, desiredH: CGFloat,
                               ratio: CGFloat) -> CGRect {
        let availW = growLeft ? anchorX : 1 - anchorX
        let availH = growUp ? anchorY : 1 - anchorY

        var width = min(desiredW, desiredH * ratio)   // 두 축 의도 중 더 제약되는 쪽
        width = min(width, availW, availH * ratio)     // 경계
        width = max(width, minSize, minSize * ratio)   // 최소
        width = min(width, availW, availH * ratio)     // 최소 보정 후 재클램프
        let height = width / ratio

        let x = growLeft ? anchorX - width : anchorX
        let y = growUp ? anchorY - height : anchorY
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// 변 핸들을 비율 유지로 리사이즈. 드래그한 축의 반대 변은 고정,
    /// 직교 축은 박스 중심을 유지하며 함께 변한다.
    private func conformEdge(side: Side, pointerX: CGFloat, pointerY: CGFloat,
                             current r: CGRect, ratio: CGFloat) -> CGRect {
        switch side {
        case .leading, .trailing:
            let fixedX = (side == .trailing) ? r.minX : r.maxX
            let growRight = (side == .trailing)
            let cy = r.midY
            let availW = growRight ? 1 - fixedX : fixedX
            let availHCentered = 2 * min(cy, 1 - cy)   // 중심 고정 시 최대 높이

            var width = growRight ? (pointerX - fixedX) : (fixedX - pointerX)
            width = min(width, availW, availHCentered * ratio)
            width = max(width, minSize, minSize * ratio)
            width = min(width, availW, availHCentered * ratio)
            let height = width / ratio

            let x = growRight ? fixedX : fixedX - width
            let y = cy - height / 2
            return CGRect(x: x, y: y, width: width, height: height)

        case .top, .bottom:
            let fixedY = (side == .bottom) ? r.minY : r.maxY
            let growDown = (side == .bottom)
            let cx = r.midX
            let availH = growDown ? 1 - fixedY : fixedY
            let availWCentered = 2 * min(cx, 1 - cx)

            var height = growDown ? (pointerY - fixedY) : (fixedY - pointerY)
            height = min(height, availH, availWCentered / ratio)
            height = max(height, minSize, minSize / ratio)
            height = min(height, availH, availWCentered / ratio)
            let width = height * ratio

            let y = growDown ? fixedY : fixedY - height
            let x = cx - width / 2
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        max(lo, min(hi, v))
    }
}
