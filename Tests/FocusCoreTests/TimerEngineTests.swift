import XCTest
@testable import FocusCore

final class TimerEngineTests: XCTestCase {
    func testInitialStateIsIdleFocusRoundOne() {
        let (e, _) = makeEngine()
        XCTAssertEqual(e.phase, .focus)
        XCTAssertEqual(e.state, .idle)
        XCTAssertEqual(e.currentRound, 1)
        XCTAssertEqual(e.remaining(), 25 * 60)
        XCTAssertEqual(e.progress, 0)
    }

    func testStartRunsForFullDuration() {
        var (e, clock) = makeEngine()
        e.start()
        XCTAssertTrue(e.isRunning)
        clock.advance(60)
        XCTAssertEqual(e.remaining(), 24 * 60, accuracy: 0.001)
        XCTAssertEqual(e.progress, 1.0 / 25, accuracy: 0.0001)
    }

    func testStartWhileRunningDoesNotRestart() {
        var (e, clock) = makeEngine()
        e.start()
        clock.advance(100)
        e.start()
        XCTAssertEqual(e.remaining(), 25 * 60 - 100, accuracy: 0.001)
    }

    func testPauseFreezesRemaining() {
        var (e, clock) = makeEngine()
        e.start()
        clock.advance(300)
        e.pause()
        XCTAssertTrue(e.isPaused)
        clock.advance(10_000)
        XCTAssertEqual(e.remaining(), 25 * 60 - 300, accuracy: 0.001)
        XCTAssertNil(e.update(), "暫停中不會結束")
    }

    func testResumeContinuesFromRemaining() {
        var (e, clock) = makeEngine()
        e.start()
        clock.advance(300)
        e.pause()
        clock.advance(999)
        e.start()
        XCTAssertTrue(e.isRunning)
        XCTAssertEqual(e.remaining(), 25 * 60 - 300, accuracy: 0.001)
        clock.advance(25 * 60 - 300)
        XCTAssertNotNil(e.update())
    }

    func testPauseWhenIdleDoesNothing() {
        var (e, _) = makeEngine()
        e.pause()
        XCTAssertEqual(e.state, .idle)
    }

    func testToggleAlternates() {
        var (e, _) = makeEngine()
        e.toggle(); XCTAssertTrue(e.isRunning)
        e.toggle(); XCTAssertTrue(e.isPaused)
        e.toggle(); XCTAssertTrue(e.isRunning)
    }

    func testResetReturnsToIdleSamePhase() {
        var (e, clock) = makeEngine()
        e.start()
        clock.advance(500)
        e.reset()
        XCTAssertEqual(e.state, .idle)
        XCTAssertEqual(e.phase, .focus)
        XCTAssertEqual(e.remaining(), 25 * 60)
    }

    func testUpdateBeforeEndReturnsNil() {
        var (e, clock) = makeEngine()
        e.start()
        clock.advance(25 * 60 - 1)
        XCTAssertNil(e.update())
        XCTAssertTrue(e.isRunning)
    }

    func testFocusCompletionMovesToShortBreak() throws {
        var (e, clock) = makeEngine()
        e.label = "寫報告"
        e.start()
        clock.advance(25 * 60)
        let done = try XCTUnwrap(e.update())
        XCTAssertEqual(done.phase, .focus)
        XCTAssertEqual(done.plannedSeconds, 25 * 60)
        XCTAssertEqual(done.label, "寫報告")
        XCTAssertEqual(done.round, 1)
        XCTAssertEqual(done.nextPhase, .shortBreak)
        XCTAssertFalse(done.autoStarted)
        XCTAssertEqual(e.phase, .shortBreak)
        XCTAssertEqual(e.state, .idle)
        XCTAssertEqual(e.remaining(), 5 * 60)
    }

    func testBreakCompletionHasNoLabelAndReturnsToFocus() throws {
        var (e, clock) = makeEngine()
        e.label = "x"
        e.start(); clock.advance(25 * 60); e.update()
        e.start(); clock.advance(5 * 60)
        let done = try XCTUnwrap(e.update())
        XCTAssertEqual(done.phase, .shortBreak)
        XCTAssertNil(done.label)
        XCTAssertEqual(e.phase, .focus)
        XCTAssertEqual(e.currentRound, 2)
    }

    func testLongBreakAfterConfiguredRounds() throws {
        var cfg = TimerConfig()
        cfg.roundsBeforeLongBreak = 3
        var (e, clock) = makeEngine(cfg)
        for round in 1...3 {
            XCTAssertEqual(e.phase, .focus)
            XCTAssertEqual(e.currentRound, round)
            e.start(); clock.advance(25 * 60)
            let done = try XCTUnwrap(e.update())
            XCTAssertEqual(done.nextPhase, round == 3 ? .longBreak : .shortBreak)
            if round < 3 { e.start(); clock.advance(5 * 60); e.update() }
        }
        XCTAssertEqual(e.phase, .longBreak)
        XCTAssertEqual(e.remaining(), 15 * 60)
        XCTAssertEqual(e.currentRound, 3)
    }

    func testCycleResetsAfterLongBreak() {
        var cfg = TimerConfig(); cfg.roundsBeforeLongBreak = 2
        var (e, clock) = makeEngine(cfg)
        e.start(); clock.advance(25 * 60); e.update()      // 專注 1
        e.start(); clock.advance(5 * 60); e.update()       // 短休
        e.start(); clock.advance(25 * 60); e.update()      // 專注 2 → 長休
        XCTAssertEqual(e.phase, .longBreak)
        e.start(); clock.advance(15 * 60); e.update()
        XCTAssertEqual(e.phase, .focus)
        XCTAssertEqual(e.completedFocusRounds, 0)
        XCTAssertEqual(e.currentRound, 1)
    }

    func testSkipFocusDoesNotCountRound() {
        var (e, _) = makeEngine()
        e.skip()
        XCTAssertEqual(e.phase, .shortBreak)
        XCTAssertEqual(e.completedFocusRounds, 0)
        XCTAssertEqual(e.state, .idle)
        e.skip()
        XCTAssertEqual(e.phase, .focus)
        XCTAssertEqual(e.currentRound, 1)
    }

    func testSkipLongBreakStartsNewCycle() {
        var cfg = TimerConfig(); cfg.roundsBeforeLongBreak = 2
        var (e, clock) = makeEngine(cfg)
        e.start(); clock.advance(25 * 60); e.update()
        e.skip()   // 略過短休
        e.start(); clock.advance(25 * 60); e.update()
        XCTAssertEqual(e.phase, .longBreak)
        e.skip()
        XCTAssertEqual(e.phase, .focus)
        XCTAssertEqual(e.completedFocusRounds, 0)
    }

    func testSkipWhileRunningWithoutAutoStartGoesIdle() {
        var (e, _) = makeEngine()
        e.start()
        e.skip()
        XCTAssertEqual(e.state, .idle)
    }

    func testSkipWhileRunningWithAutoStartKeepsRunning() {
        var cfg = TimerConfig(); cfg.autoStartNext = true
        var (e, clock) = makeEngine(cfg)
        e.start()
        clock.advance(10)
        e.skip()
        XCTAssertEqual(e.phase, .shortBreak)
        XCTAssertTrue(e.isRunning)
        XCTAssertEqual(e.remaining(), 5 * 60, accuracy: 0.001)
    }

    func testAutoStartBeginsNextPhaseOnCompletion() throws {
        var cfg = TimerConfig(); cfg.autoStartNext = true
        var (e, clock) = makeEngine(cfg)
        e.start(); clock.advance(25 * 60)
        let done = try XCTUnwrap(e.update())
        XCTAssertTrue(done.autoStarted)
        XCTAssertTrue(e.isRunning)
        XCTAssertEqual(e.phase, .shortBreak)
        XCTAssertEqual(e.remaining(), 5 * 60, accuracy: 0.001)
    }

    func testResetCycleGoesBackToFirstFocus() {
        var (e, clock) = makeEngine()
        e.start(); clock.advance(25 * 60); e.update()
        e.resetCycle()
        XCTAssertEqual(e.phase, .focus)
        XCTAssertEqual(e.currentRound, 1)
        XCTAssertEqual(e.state, .idle)
    }

    func testApplyConfigChangesIdleDuration() {
        var (e, _) = makeEngine()
        var cfg = e.config; cfg.focusMinutes = 50
        e.apply(config: cfg)
        XCTAssertEqual(e.remaining(), 50 * 60)
    }

    func testApplyConfigKeepsRunningEndTime() {
        var (e, clock) = makeEngine()
        e.start(); clock.advance(60)
        var cfg = e.config; cfg.focusMinutes = 90
        e.apply(config: cfg)
        XCTAssertEqual(e.remaining(), 24 * 60, accuracy: 0.001)
    }

    func testApplyConfigClampsInvalidValues() {
        var (e, _) = makeEngine()
        e.apply(config: TimerConfig(focusMinutes: 0, shortBreakMinutes: 9999, longBreakMinutes: -3, roundsBeforeLongBreak: 1))
        XCTAssertEqual(e.config.focusMinutes, 1)
        XCTAssertEqual(e.config.shortBreakMinutes, 240)
        XCTAssertEqual(e.config.longBreakMinutes, 1)
        XCTAssertEqual(e.config.roundsBeforeLongBreak, 2)
    }
}
