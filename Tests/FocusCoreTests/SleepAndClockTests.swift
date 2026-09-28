import XCTest
@testable import FocusCore

/// 睡眠 / 喚醒 / 系統時間被改的情境。
final class SleepAndClockTests: XCTestCase {
    /// 兩個獨立的時鐘：牆上時間可以被亂改，單調時鐘只會前進。
    final class Clocks: TimeSource {
        var monotonic: TimeInterval = 500
        var wall: Date = date(2026, 5, 1, 9)
        func now() -> TimeInterval { monotonic }
        func sleep(_ seconds: TimeInterval) { monotonic += seconds; wall.addTimeInterval(seconds) }
    }

    func testSleepShorterThanRemainingKeepsCountingCorrectly() {
        let clocks = Clocks()
        var e = TimerEngine(clock: clocks)
        e.start()
        clocks.monotonic += 600            // 清醒 10 分鐘
        clocks.sleep(300)                  // 睡 5 分鐘
        XCTAssertEqual(e.remaining(), 25 * 60 - 900, accuracy: 0.001)
        XCTAssertNil(e.update())
    }

    func testSleepPastEndCompletesExactlyOnceOnWake() throws {
        let clocks = Clocks()
        var e = TimerEngine(clock: clocks)
        e.label = "讀書"
        e.start()
        clocks.sleep(3 * 3600)             // 睡 3 小時
        XCTAssertEqual(e.remaining(), 0)
        let done = try XCTUnwrap(e.update())
        XCTAssertEqual(done.phase, .focus)
        XCTAssertEqual(done.label, "讀書")
        XCTAssertNil(e.update(), "同一段不能重複結束")
        XCTAssertEqual(e.phase, .shortBreak)
    }

    func testAutoStartAfterLongSleepDoesNotChainThroughPhases() throws {
        let clocks = Clocks()
        var cfg = TimerConfig(); cfg.autoStartNext = true
        var e = TimerEngine(config: cfg, clock: clocks)
        e.start()
        clocks.sleep(10 * 3600)
        let done = try XCTUnwrap(e.update())
        XCTAssertTrue(done.autoStarted)
        XCTAssertEqual(e.phase, .shortBreak)
        XCTAssertEqual(e.remaining(), 5 * 60, accuracy: 0.001, "下一段從醒來的那一刻起算")
        XCTAssertNil(e.update())
    }

    func testPausedTimerIsUnaffectedBySleep() {
        let clocks = Clocks()
        var e = TimerEngine(clock: clocks)
        e.start()
        clocks.monotonic += 120
        e.pause()
        clocks.sleep(8 * 3600)
        XCTAssertEqual(e.remaining(), 25 * 60 - 120, accuracy: 0.001)
        XCTAssertNil(e.update())
    }

    func testWallClockChangeDoesNotAffectCountdown() {
        let clocks = Clocks()
        var e = TimerEngine(clock: clocks)
        e.start()
        clocks.monotonic += 60
        clocks.wall = date(2000, 1, 1)     // 使用者把系統時間往回調
        XCTAssertEqual(e.remaining(), 24 * 60, accuracy: 0.001)
        clocks.wall = date(2099, 1, 1)     // 又往未來調
        XCTAssertEqual(e.remaining(), 24 * 60, accuracy: 0.001)
        XCTAssertNil(e.update())
    }

    func testUpdateFrequencyDoesNotMatter() throws {
        let clocks = Clocks()
        var e = TimerEngine(clock: clocks)
        e.start()
        // 完全不呼叫 update，直接跳到結束後
        clocks.monotonic += 25 * 60 + 0.4
        XCTAssertNotNil(try XCTUnwrap(e.update()))
    }

    func testSystemTimeSourceIsMonotonic() {
        let s = SystemTimeSource()
        let a = s.now()
        Thread.sleep(forTimeInterval: 0.02)
        let b = s.now()
        XCTAssertGreaterThan(b, a)
        XCTAssertGreaterThanOrEqual(a, 0)
    }

    func testClockFormatting() {
        XCTAssertEqual(TimeFormat.clock(25 * 60), "25:00")
        XCTAssertEqual(TimeFormat.clock(24 * 60 + 13), "24:13")
        XCTAssertEqual(TimeFormat.clock(0.2), "00:01", "還沒結束就不顯示 00:00")
        XCTAssertEqual(TimeFormat.clock(0), "00:00")
        XCTAssertEqual(TimeFormat.clock(-5), "00:00")
        XCTAssertEqual(TimeFormat.clock(90 * 60), "90:00")
    }
}
