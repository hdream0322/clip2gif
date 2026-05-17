import AppKit

/// 도크 아이콘 둘레에 진행률 링을 그려준다. 다른 앱(예: 사파리 다운로드, Handbrake)에서 보이는 그 효과.
@MainActor
enum DockProgress {
    private final class TileView: NSView {
        var progress: Double = 0 {
            didSet { needsDisplay = true }
        }

        override func draw(_ dirtyRect: NSRect) {
            NSApp.applicationIconImage?.draw(in: bounds)
            guard progress > 0, progress < 1 else { return }

            let lineWidth: CGFloat = 9
            let inset = lineWidth / 2 + 2
            let ringRect = bounds.insetBy(dx: inset, dy: inset)

            let bg = NSBezierPath(ovalIn: ringRect)
            bg.lineWidth = lineWidth
            NSColor.black.withAlphaComponent(0.45).setStroke()
            bg.stroke()

            let center = NSPoint(x: ringRect.midX, y: ringRect.midY)
            let radius = min(ringRect.width, ringRect.height) / 2
            let start: CGFloat = 90
            let end = start - 360 * CGFloat(progress)
            let arc = NSBezierPath()
            arc.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: start,
                endAngle: end,
                clockwise: true
            )
            arc.lineWidth = lineWidth
            arc.lineCapStyle = .round
            NSColor.controlAccentColor.setStroke()
            arc.stroke()
        }
    }

    private static let tileView: TileView = {
        let v = TileView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
        v.wantsLayer = true
        return v
    }()

    /// progress 가 nil 이거나 0/1 이면 도크 표시 해제.
    static func set(_ progress: Double?) {
        let tile = NSApp.dockTile
        if let p = progress, p > 0, p < 1 {
            tileView.progress = p
            if tile.contentView !== tileView {
                tile.contentView = tileView
            }
            tile.display()
        } else {
            if tile.contentView != nil {
                tile.contentView = nil
            }
            tile.display()
        }
    }
}
