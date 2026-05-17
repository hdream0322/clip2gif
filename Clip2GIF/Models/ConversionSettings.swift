import Foundation
import CoreGraphics

/// 크롭 박스 가로:세로 비율 고정 옵션. ratio 는 "출력 픽셀" 기준 가로/세로.
enum AspectLock: String, CaseIterable, Identifiable, Equatable {
    case free
    case square
    case r4_3
    case r3_4
    case r16_9
    case r9_16

    var id: String { rawValue }

    var label: String {
        switch self {
        case .free:  return "자유"
        case .square: return "1:1"
        case .r4_3:  return "4:3"
        case .r3_4:  return "3:4"
        case .r16_9: return "16:9"
        case .r9_16: return "9:16"
        }
    }

    /// 출력 픽셀 기준 가로/세로 비율. 자유면 nil.
    var pixelRatio: CGFloat? {
        switch self {
        case .free:  return nil
        case .square: return 1
        case .r4_3:  return 4.0 / 3.0
        case .r3_4:  return 3.0 / 4.0
        case .r16_9: return 16.0 / 9.0
        case .r9_16: return 9.0 / 16.0
        }
    }
}

struct ConversionSettings: Equatable {
    var trimStart: TimeInterval = 0
    var trimEnd: TimeInterval = 0
    var fps: Int = 15
    var quality: Int = 80
    /// 재생 속도 배율. 1.0=원본, 2.0=2배 빠름, 0.5=절반 속도. 0.5~10.0.
    var speed: Double = 1.0
    /// 정규화 좌표(0~1). 기본은 전체 영역.
    var cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    /// 크롭 박스 비율 고정. 자유면 자유 변형.
    var aspectLock: AspectLock = .free
    /// 출력 GIF 가로/세로 크기 배율 (퍼센트). 25/50/75/100.
    var scalePercent: Int = 100
    /// 출력 GIF 가 무한 반복할지. false 면 1회 재생.
    var loopForever: Bool = true
    /// 끝에서 역재생으로 돌아오는 왕복(bounce/palindrome). 프레임을 [forward + reverse] 로 확장.
    var bounce: Bool = false

    static let `default` = ConversionSettings()

    func effectiveTrimEnd(duration: TimeInterval) -> TimeInterval {
        trimEnd == 0 ? duration : trimEnd
    }

    /// 정규화 cropRect → 픽셀 좌표(짝수로 정렬, 최소 2px 보장).
    func pixelCropRect(for naturalSize: CGSize) -> CGRect {
        let x = (cropRect.minX * naturalSize.width).rounded()
        let y = (cropRect.minY * naturalSize.height).rounded()
        let w = max(2, (cropRect.width * naturalSize.width).rounded())
        let h = max(2, (cropRect.height * naturalSize.height).rounded())
        let evenW = w.truncatingRemainder(dividingBy: 2) == 0 ? w : w - 1
        let evenH = h.truncatingRemainder(dividingBy: 2) == 0 ? h : h - 1
        return CGRect(x: x, y: y, width: max(2, evenW), height: max(2, evenH))
    }

    /// 크롭 + 현재 scalePercent 적용 후의 최종 출력 픽셀 크기.
    func pixelOutputSize(for naturalSize: CGSize) -> CGSize {
        pixelOutputSize(for: naturalSize, scalePercent: scalePercent)
    }

    /// 크롭 + 임의 배율 적용 후의 출력 픽셀 크기.
    func pixelOutputSize(for naturalSize: CGSize, scalePercent percent: Int) -> CGSize {
        let crop = pixelCropRect(for: naturalSize)
        let scale = max(0.05, Double(percent) / 100.0)
        let w = (Double(crop.width) * scale).rounded()
        let h = (Double(crop.height) * scale).rounded()
        let evenW = Int(w).isMultiple(of: 2) ? w : w - 1
        let evenH = Int(h).isMultiple(of: 2) ? h : h - 1
        return CGSize(width: max(2, evenW), height: max(2, evenH))
    }

    var isFullFrame: Bool {
        cropRect == CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    /// 현재 비율 고정에서 크롭 박스가 가져야 할 "정규화 좌표 기준 가로/세로"(width/height).
    /// 출력 픽셀 비율 R 을 유지하려면 정규화 비율은 R * (H/W) 가 되어야 함.
    /// 자유면 nil.
    func normalizedBoxRatio(for naturalSize: CGSize) -> CGFloat? {
        guard let r = aspectLock.pixelRatio,
              naturalSize.width > 0, naturalSize.height > 0 else { return nil }
        return r * naturalSize.height / naturalSize.width
    }

    /// 주어진 출력 픽셀 비율 R 에 맞춰, 전체 프레임 안에서 가장 크게 가운데 정렬된 정규화 크롭 박스.
    static func centeredCropRect(pixelRatio r: CGFloat, naturalSize: CGSize) -> CGRect {
        guard naturalSize.width > 0, naturalSize.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        let boxRatio = r * naturalSize.height / naturalSize.width // = bw / bh
        var bw: CGFloat = 1
        var bh: CGFloat = 1
        if boxRatio >= 1 {
            bw = 1
            bh = 1 / boxRatio
        } else {
            bh = 1
            bw = boxRatio
        }
        return CGRect(x: (1 - bw) / 2, y: (1 - bh) / 2, width: bw, height: bh)
    }
}
