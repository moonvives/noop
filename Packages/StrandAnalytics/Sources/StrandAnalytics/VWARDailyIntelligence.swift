import Foundation

/// A compact, vendor-neutral snapshot used by the VWAR Loop Life daily explanation layer.
///
/// The interpreter deliberately works with already-audited daily values. It does not infer a missing
/// measurement, diagnose a condition, or claim that a change was caused by another signal.
public struct VWARDailySignals: Equatable, Sendable {
    public let day: String
    public let recovery: Double?
    public let load: Double?
    public let sleep: Double?
    public let hrvMilliseconds: Double?
    public let restingHeartRate: Double?
    public let steps: Double?

    public init(
        day: String,
        recovery: Double? = nil,
        load: Double? = nil,
        sleep: Double? = nil,
        hrvMilliseconds: Double? = nil,
        restingHeartRate: Double? = nil,
        steps: Double? = nil
    ) {
        self.day = day
        self.recovery = recovery
        self.load = load
        self.sleep = sleep
        self.hrvMilliseconds = hrvMilliseconds
        self.restingHeartRate = restingHeartRate
        self.steps = steps
    }
}

public enum VWARDailyFocus: String, CaseIterable, Identifiable, Sendable {
    case recovery
    case sleep
    case load

    public var id: String { rawValue }
}

public enum VWARSignalMetric: String, CaseIterable, Identifiable, Sendable {
    case recovery
    case load
    case sleep
    case hrv
    case restingHeartRate
    case steps

    public var id: String { rawValue }
}

public enum VWARSignalPosition: String, Equatable, Sendable {
    case belowBaseline
    case nearBaseline
    case aboveBaseline
}

public enum VWARDataConfidence: Equatable, Sendable {
    case missing
    case calibrating(days: Int)
    case building(days: Int)
    case solid(days: Int)

    public var dayCount: Int {
        switch self {
        case .missing: return 0
        case .calibrating(let days), .building(let days), .solid(let days): return days
        }
    }
}

public struct VWARSignalComparison: Equatable, Sendable, Identifiable {
    public let metric: VWARSignalMetric
    public let current: Double
    public let baselineMedian: Double
    /// Signed relative difference from the personal median. A positive value only means "higher";
    /// it is not automatically better (for example, a higher resting heart rate can be undesirable).
    public let relativeDifference: Double
    public let position: VWARSignalPosition
    public let referenceDays: Int

    public var id: VWARSignalMetric { metric }
}

public struct VWARDailyInsight: Equatable, Sendable {
    public let focus: VWARDailyFocus
    public let score: Double?
    public let confidence: VWARDataConfidence
    public let primaryPosition: VWARSignalPosition?
    public let comparisons: [VWARSignalComparison]
}

/// Deterministic, local-first daily context. It compares a selected day with up to 28 prior,
/// non-missing days from the same person and returns structured facts for the UI to explain.
public enum VWARDailyIntelligence {
    public static func analyze(
        current: VWARDailySignals?,
        history: [VWARDailySignals],
        focus: VWARDailyFocus
    ) -> VWARDailyInsight {
        guard let current else {
            return VWARDailyInsight(
                focus: focus,
                score: nil,
                confidence: .missing,
                primaryPosition: nil,
                comparisons: []
            )
        }

        let reference = Array(history.filter { $0.day != current.day }.suffix(28))
        let metrics = metrics(for: focus)
        let comparisons = metrics.compactMap { metric in
            comparison(metric: metric, current: current, history: reference)
        }
        let primary = primaryMetric(for: focus)
        let primaryReferenceDays = reference.compactMap { value(primary, from: $0) }.count
        let confidence: VWARDataConfidence
        switch primaryReferenceDays {
        case 14...: confidence = .solid(days: primaryReferenceDays)
        case 7..<14: confidence = .building(days: primaryReferenceDays)
        case 1..<7: confidence = .calibrating(days: primaryReferenceDays)
        default: confidence = .missing
        }

        return VWARDailyInsight(
            focus: focus,
            score: value(primary, from: current),
            confidence: confidence,
            primaryPosition: comparisons.first(where: { $0.metric == primary })?.position,
            comparisons: comparisons
        )
    }

    private static func comparison(
        metric: VWARSignalMetric,
        current: VWARDailySignals,
        history: [VWARDailySignals]
    ) -> VWARSignalComparison? {
        guard let currentValue = value(metric, from: current) else { return nil }
        let population = history.compactMap { value(metric, from: $0) }
        guard population.count >= 5, let baseline = median(population) else { return nil }
        let relativeDifference = (currentValue - baseline) / max(abs(baseline), 1)
        let position: VWARSignalPosition
        switch relativeDifference {
        case ..<(-0.05): position = .belowBaseline
        case 0.05...: position = .aboveBaseline
        default: position = .nearBaseline
        }
        return VWARSignalComparison(
            metric: metric,
            current: currentValue,
            baselineMedian: baseline,
            relativeDifference: relativeDifference,
            position: position,
            referenceDays: population.count
        )
    }

    private static func metrics(for focus: VWARDailyFocus) -> [VWARSignalMetric] {
        switch focus {
        case .recovery: return [.recovery, .hrv, .restingHeartRate, .sleep]
        case .sleep: return [.sleep, .hrv, .restingHeartRate]
        case .load: return [.load, .steps, .restingHeartRate]
        }
    }

    private static func primaryMetric(for focus: VWARDailyFocus) -> VWARSignalMetric {
        switch focus {
        case .recovery: return .recovery
        case .sleep: return .sleep
        case .load: return .load
        }
    }

    private static func value(_ metric: VWARSignalMetric, from signals: VWARDailySignals) -> Double? {
        switch metric {
        case .recovery: return signals.recovery
        case .load: return signals.load
        case .sleep: return signals.sleep
        case .hrv: return signals.hrvMilliseconds
        case .restingHeartRate: return signals.restingHeartRate
        case .steps: return signals.steps
        }
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
