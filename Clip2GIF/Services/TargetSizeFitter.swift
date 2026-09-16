import Foundation

/// 목표 용량에 맞는 출력 배율(scalePercent)·화질(quality)을 실측 반복으로 찾는다.
///
/// 전략(하이브리드 1단계): 배율을 큰 것부터 내리며, 각 배율에서 화질을
/// 이진 탐색해 "목표 안에 드는 가장 큰 배율 + 그 안에서 최대 화질"을 고른다.
/// 측정은 PreflightEstimator(대표 구간을 실제 gifski 로 인코딩 후 외삽,
/// 앱이 ±10% 로 신뢰하는 실측)로 하므로 전체 인코딩보다 훨씬 빠르다.
/// 남은 ±10% 오차는 변환 시점의 실측 재인코딩 보정(2단계)에서 흡수한다.
enum TargetSizeFitter {
    /// 화질 그대로 두고 우선 시도할 표준 배율(큰 것부터).
    private static let scaleSteps = [100, 75, 50, 25]

    /// 탐색 진행 1회 보고 (UI 라이브 표시용).
    struct Probe: Equatable {
        let index: Int
        let scalePercent: Int
        let quality: Int
        let measuredBytes: Int64
    }

    struct SearchResult: Equatable {
        let scalePercent: Int
        let quality: Int
        let predictedBytes: Int64
        /// 최소 설정으로도 목표를 못 맞추면 false (최선만 반환).
        let feasible: Bool
        let probes: Int
    }

    /// 반복 실측 탐색. 취소 시 CancellationError 를 던진다.
    /// - Parameters:
    ///   - source: 원본 영상.
    ///   - baseSettings: 구간·크롭 등 비탐색 설정의 기준점.
    ///   - targetBytes: 목표 상한.
    ///   - onProbe: 매 측정마다 호출(메인 액터 보장 안 함 — 호출 측에서 디스패치).
    static func search(
        source: VideoSource,
        baseSettings: ConversionSettings,
        targetBytes: Int64,
        onProbe: @escaping (Probe) -> Void
    ) async throws -> SearchResult {
        let target = max(1, targetBytes)
        var cache: [Int: Int64] = [:]   // key: scale*1000 + quality
        var probeCount = 0

        func measure(scale: Int, quality: Int) async throws -> Int64 {
            let key = scale * 1000 + quality
            if let hit = cache[key] { return hit }
            try Task.checkCancellation()
            var s = baseSettings
            s.scalePercent = scale
            s.quality = quality
            let bytes = try await PreflightEstimator.estimate(
                source: source, settings: s
            ).bytes
            cache[key] = bytes
            probeCount += 1
            onProbe(Probe(
                index: probeCount, scalePercent: scale,
                quality: quality, measuredBytes: bytes
            ))
            return bytes
        }

        var lastScale = scaleSteps.last ?? 25
        var lastBytes: Int64 = 0

        for scale in scaleSteps {
            lastScale = scale
            // 이 배율에서 최저 화질로도 초과면 다음(더 작은) 배율로.
            let atMin = try await measure(scale: scale, quality: 1)
            lastBytes = atMin
            if atMin > target { continue }

            // 최고 화질이 이미 들어가면 더 볼 것 없음.
            let atMax = try await measure(scale: scale, quality: 100)
            if atMax <= target {
                return SearchResult(
                    scalePercent: scale, quality: 100,
                    predictedBytes: atMax, feasible: true, probes: probeCount
                )
            }

            // q=1 OK, q=100 초과 → 목표 이하인 "최대 화질" 이진 탐색.
            var lo = 1, hi = 100
            var bestQ = 1
            var bestBytes = atMin
            while lo <= hi {
                let mid = (lo + hi) / 2
                let m = try await measure(scale: scale, quality: mid)
                if m <= target {
                    bestQ = mid
                    bestBytes = m
                    lo = mid + 1
                } else {
                    hi = mid - 1
                }
            }
            return SearchResult(
                scalePercent: scale, quality: bestQ,
                predictedBytes: bestBytes, feasible: true, probes: probeCount
            )
        }

        // 어떤 표준 배율로도 목표 달성 불가 — 최소 설정을 최선으로 반환.
        return SearchResult(
            scalePercent: lastScale, quality: 1,
            predictedBytes: lastBytes, feasible: false, probes: probeCount
        )
    }
}
