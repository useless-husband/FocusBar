import XCTest
@testable import FocusCore

final class StatsTests: XCTestCase {
    let cal = utcCalendar()
    var stats: StatsCalculator { StatsCalculator(calendar: cal) }

    func session(_ end: Date, minutes: Int, label: String? = nil) -> FocusSession {
        FocusSession(endedAt: end, seconds: minutes * 60, label: label)
    }

    func testEmptyTodayIsZero() {
        let t = stats.total(on: date(2026, 5, 1, 12), in: [])
        XCTAssertEqual(t.seconds, 0)
        XCTAssertEqual(t.rounds, 0)
    }

    func testTodayTotalsSumMinutesAndRounds() {
        let s = [session(date(2026, 5, 1, 9, 30), minutes: 25),
                 session(date(2026, 5, 1, 14), minutes: 50),
                 session(date(2026, 4, 30, 14), minutes: 90)]
        let t = stats.total(on: date(2026, 5, 1, 23), in: s)
        XCTAssertEqual(t.minutes, 75, accuracy: 0.001)
        XCTAssertEqual(t.rounds, 2)
    }

    func testSessionSpanningMidnightIsSplitByOverlap() {
        // 23:50 開始、00:15 結束（25 分鐘）：前一天 10 分鐘、後一天 15 分鐘
        let s = [session(date(2026, 5, 2, 0, 15), minutes: 25)]
        let d1 = stats.total(on: date(2026, 5, 1), in: s)
        let d2 = stats.total(on: date(2026, 5, 2), in: s)
        XCTAssertEqual(d1.minutes, 10, accuracy: 0.001)
        XCTAssertEqual(d2.minutes, 15, accuracy: 0.001)
        XCTAssertEqual(d1.rounds, 0)
        XCTAssertEqual(d2.rounds, 1, "輪數算在結束那天")
    }

    func testSessionEndingExactlyAtMidnightBelongsToPreviousDay() {
        let s = [session(date(2026, 5, 2, 0, 0), minutes: 25)]
        XCTAssertEqual(stats.total(on: date(2026, 5, 1), in: s).minutes, 25, accuracy: 0.001)
        XCTAssertEqual(stats.total(on: date(2026, 5, 2), in: s).seconds, 0)
        XCTAssertEqual(stats.total(on: date(2026, 5, 2), in: s).rounds, 1)
    }

    func testLastSevenDaysIncludesEmptyDaysOldestFirst() {
        let now = date(2026, 5, 7, 10)
        let s = [session(date(2026, 5, 7, 9), minutes: 25),
                 session(date(2026, 5, 5, 9), minutes: 50),
                 session(date(2026, 4, 20, 9), minutes: 60)]   // 範圍外
        let days = stats.lastDays(7, endingAt: now, in: s)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first?.day, date(2026, 5, 1))
        XCTAssertEqual(days.last?.day, date(2026, 5, 7))
        XCTAssertEqual(days.map { Int($0.minutes) }, [0, 0, 0, 0, 50, 0, 25])
        XCTAssertEqual(days[4].minutes, 50, accuracy: 0.001)
        XCTAssertEqual(days[6].minutes, 25, accuracy: 0.001)
        XCTAssertEqual(days.reduce(0) { $0 + $1.minutes }, 75, accuracy: 0.001)
    }

    func testLastDaysAcrossMonthBoundary() {
        let days = stats.lastDays(3, endingAt: date(2026, 3, 1, 8), in: [])
        XCTAssertEqual(days.map(\.day), [date(2026, 2, 27), date(2026, 2, 28), date(2026, 3, 1)])
    }

    func testLastDaysWithNonPositiveCountIsEmpty() {
        XCTAssertTrue(stats.lastDays(0, endingAt: Date(), in: []).isEmpty)
    }

    func testDayBoundaryFollowsCalendarTimeZone() {
        var taipei = Calendar(identifier: .gregorian)
        taipei.timeZone = TimeZone(identifier: "Asia/Taipei")!
        // UTC 20:00 = 台北隔天 04:00
        let s = [session(date(2026, 5, 1, 20), minutes: 25)]
        let calc = StatsCalculator(calendar: taipei)
        let taipeiMay2 = taipei.date(from: DateComponents(year: 2026, month: 5, day: 2, hour: 12))!
        XCTAssertEqual(calc.total(on: taipeiMay2, in: s).rounds, 1)
        XCTAssertEqual(stats.total(on: date(2026, 5, 2), in: s).rounds, 0)
    }

    func testLabelTotalsGroupAndSort() {
        let now = date(2026, 5, 7, 20)
        let s = [session(date(2026, 5, 7, 9), minutes: 25, label: "英文"),
                 session(date(2026, 5, 6, 9), minutes: 25, label: "英文"),
                 session(date(2026, 5, 6, 12), minutes: 50, label: "程式"),
                 session(date(2026, 5, 5, 12), minutes: 10, label: nil),
                 session(date(2026, 4, 1, 12), minutes: 999, label: "太久以前")]
        let totals = stats.labelTotals(lastDays: 7, endingAt: now, in: s)
        XCTAssertEqual(totals.map(\.label), ["程式", "英文", nil])
        XCTAssertEqual(totals[0].minutes, 50, accuracy: 0.001)
        XCTAssertEqual(totals[1].minutes, 50, accuracy: 0.001)
        XCTAssertEqual(totals[1].rounds, 2)
        XCTAssertEqual(totals[2].rounds, 1)
    }

    func testLabelTotalsRespectDayRange() {
        let now = date(2026, 5, 7, 20)
        let s = [session(date(2026, 5, 7, 9), minutes: 25, label: "A"),
                 session(date(2026, 5, 6, 9), minutes: 25, label: "B")]
        let today = stats.labelTotals(lastDays: 1, endingAt: now, in: s)
        XCTAssertEqual(today.map(\.label), ["A"])
    }

    func testRecentLabelsAreDistinctNewestFirst() {
        let s = [session(date(2026, 5, 1), minutes: 25, label: "A"),
                 session(date(2026, 5, 3), minutes: 25, label: "B"),
                 session(date(2026, 5, 2), minutes: 25, label: "A"),
                 session(date(2026, 5, 4), minutes: 25, label: nil)]
        XCTAssertEqual(stats.recentLabels(5, in: s), ["B", "A"])
        XCTAssertEqual(stats.recentLabels(1, in: s), ["B"])
    }

    func testSessionStartedAtDerivedFromEnd() {
        let s = session(date(2026, 5, 1, 10), minutes: 25)
        XCTAssertEqual(s.startedAt, date(2026, 5, 1, 9, 35))
    }
}
