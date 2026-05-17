import Foundation

enum ConversionState: Equatable {
    case idle
    case extracting(progress: Double)
    case encoding(progress: Double)
    case done(URL)
    case failed(ConversionError)
}

enum ConversionError: LocalizedError, Equatable {
    case ioFailed(String)
    case gifskiCrashed(code: Int32, stderr: String)
    case unsupportedCodec
    case cancelled
    case binaryMissing

    var errorDescription: String? {
        switch self {
        case .ioFailed(let msg):
            return "파일 입출력 오류: \(msg)"
        case .gifskiCrashed(let code, let stderr):
            return "GIF 인코더가 오류 코드 \(code)로 종료되었습니다. \(stderr)"
        case .unsupportedCodec:
            return "지원하지 않는 비디오 코덱입니다."
        case .cancelled:
            return "변환이 취소되었습니다."
        case .binaryMissing:
            return "gifski 실행 파일을 찾을 수 없습니다."
        }
    }
}

@MainActor
final class ConversionJob: ObservableObject {
    @Published var state: ConversionState = .idle
    @Published var stepName: String = ""
    @Published var detail: String = ""
    @Published var startedAt: Date?
    @Published var totalFrames: Int = 0
    @Published var currentFrame: Int = 0

    /// 전체 변환 과정에서 프레임 추출이 차지하는 비중. 나머지가 인코딩.
    static let extractWeight: Double = 0.55

    /// 단일 단계 진행률 (0~1).
    var stepProgress: Double {
        switch state {
        case .extracting(let p), .encoding(let p):
            return p
        case .done:
            return 1
        default:
            return 0
        }
    }

    /// 전체 변환 과정 진행률 (0~1).
    var overallProgress: Double {
        switch state {
        case .extracting(let p):
            return max(0, min(1, p)) * Self.extractWeight
        case .encoding(let p):
            return Self.extractWeight + max(0, min(1, p)) * (1 - Self.extractWeight)
        case .done:
            return 1
        default:
            return 0
        }
    }

    var isRunning: Bool {
        switch state {
        case .extracting, .encoding:
            return true
        default:
            return false
        }
    }

    var elapsedSeconds: Double {
        guard let startedAt else { return 0 }
        return Date().timeIntervalSince(startedAt)
    }

    /// 남은 시간 추정. 진행률이 너무 작으면 nil 반환.
    var etaSeconds: Double? {
        let p = overallProgress
        guard isRunning, p > 0.02 else { return nil }
        let total = elapsedSeconds / p
        return max(0, total - elapsedSeconds)
    }

    func reset() {
        state = .idle
        stepName = ""
        detail = ""
        startedAt = nil
        totalFrames = 0
        currentFrame = 0
    }
}
