import Foundation
import Combine

/// 배치 변환 큐의 한 항목 상태.
enum BatchItemStatus: Equatable {
    case waiting
    case processing
    case done
    case failed(String)
    /// 사용자 취소로 처리 못 한 잔여 항목.
    case skipped

    var label: String {
        switch self {
        case .waiting:    return "대기"
        case .processing: return "변환 중"
        case .done:       return "완료"
        case .failed:     return "실패"
        case .skipped:    return "건너뜀"
        }
    }

    var systemImage: String {
        switch self {
        case .waiting:    return "clock"
        case .processing: return "arrow.triangle.2.circlepath"
        case .done:       return "checkmark.circle.fill"
        case .failed:     return "exclamationmark.triangle.fill"
        case .skipped:    return "minus.circle"
        }
    }
}

struct BatchItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var status: BatchItemStatus = .waiting
    /// 완료 시 생성된 GIF 경로.
    var outputURL: URL?
}

/// 배치 변환 진행 현황을 UI 에 중계하는 옵저버블 큐.
/// 모든 변경은 메인 액터에서 일어난다(runBatch 가 MainActor.run 으로 갱신).
@MainActor
final class BatchQueue: ObservableObject {
    @Published var items: [BatchItem] = []
    /// 배치 작업이 진행 중인지 (시트 표시/취소 버튼 노출 제어).
    @Published var isRunning = false
    /// 작업 종료 후 요약 노출 여부.
    @Published var finished = false

    func load(_ urls: [URL]) {
        items = urls.map { BatchItem(url: $0) }
        isRunning = true
        finished = false
    }

    private func index(of url: URL) -> Int? {
        items.firstIndex { $0.url == url }
    }

    func mark(_ url: URL, _ status: BatchItemStatus, output: URL? = nil) {
        guard let i = index(of: url) else { return }
        items[i].status = status
        if let output { items[i].outputURL = output }
    }

    /// 취소 시점에 아직 대기/진행 중인 항목을 건너뜀으로 표시.
    func markRemainingSkipped() {
        for i in items.indices {
            if items[i].status == .waiting || items[i].status == .processing {
                items[i].status = .skipped
            }
        }
    }

    func finish() {
        isRunning = false
        finished = true
    }

    var doneCount: Int { items.filter { $0.status == .done }.count }
    var failedCount: Int {
        items.filter {
            if case .failed = $0.status { return true } else { return false }
        }.count
    }
}
