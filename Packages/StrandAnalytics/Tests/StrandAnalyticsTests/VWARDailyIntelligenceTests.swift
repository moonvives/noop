import XCTest
@testable import StrandAnalytics

final class VWARDailyIntelligenceTests: XCTestCase {
    func testComparesSelectedDayWithPersonalMedian() {
        let history = (1...14).map { day in
            VWARDailySignals(
                day: String(format: "2026-06-%02d", day),
                recovery: 60,
                load: 40,
                sleep: 80,
                hrvMilliseconds: 50,
                restingHeartRate: 60,
                steps: 8_000
            )
        }
        let current = VWARDailySignals(
            day: "2026-07-13",
            recovery: 72,
            load: 40,
            sleep: 80,
            hrvMilliseconds: 55,
            restingHeartRate: 57,
            steps: 8_000
        )

        let result = VWARDailyIntelligence.analyze(current: current, history: history, focus: .recovery)

        XCTAssertEqual(result.confidence, .solid(days: 14))
        XCTAssertEqual(result.primaryPosition, .aboveBaseline)
        XCTAssertEqual(result.comparisons.first?.metric, .recovery)
        XCTAssertEqual(result.comparisons.first?.baselineMedian, 60)
        XCTAssertEqual(result.comparisons.first?.relativeDifference ?? 0, 0.2, accuracy: 0.0001)
    }

    func testSelectedDayIsExcludedFromItsOwnReferencePopulation() {
        var history = (1...5).map { day in
            VWARDailySignals(day: "day-\(day)", load: 20)
        }
        let current = VWARDailySignals(day: "selected", load: 100)
        history.append(current)

        let result = VWARDailyIntelligence.analyze(current: current, history: history, focus: .load)

        XCTAssertEqual(result.comparisons.first?.baselineMedian, 20)
        XCTAssertEqual(result.primaryPosition, .aboveBaseline)
    }

    func testFivePercentBandIsReportedAsNearBaseline() {
        let history = (1...7).map { VWARDailySignals(day: "day-\($0)", sleep: 80) }
        let current = VWARDailySignals(day: "selected", sleep: 83.9)

        let result = VWARDailyIntelligence.analyze(current: current, history: history, focus: .sleep)

        XCTAssertEqual(result.confidence, .building(days: 7))
        XCTAssertEqual(result.primaryPosition, .nearBaseline)
    }

    func testMissingValuesStayMissingInsteadOfBeingInferred() {
        let history = (1...20).map { VWARDailySignals(day: "day-\($0)", recovery: 70) }
        let result = VWARDailyIntelligence.analyze(
            current: VWARDailySignals(day: "selected"),
            history: history,
            focus: .recovery
        )

        XCTAssertNil(result.score)
        XCTAssertTrue(result.comparisons.isEmpty)
        XCTAssertEqual(result.confidence, .solid(days: 20))
    }

    func testNoSelectedDayProducesExplicitMissingResult() {
        let result = VWARDailyIntelligence.analyze(current: nil, history: [], focus: .recovery)

        XCTAssertNil(result.score)
        XCTAssertEqual(result.confidence, .missing)
        XCTAssertNil(result.primaryPosition)
        XCTAssertTrue(result.comparisons.isEmpty)
    }
}
