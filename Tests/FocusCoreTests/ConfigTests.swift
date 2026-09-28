import XCTest
@testable import FocusCore

final class ConfigTests: XCTestCase {
    func testPresetMinutes() {
        let base = TimerConfig(roundsBeforeLongBreak: 5, autoStartNext: true)
        let deep = Preset.deep.applied(to: base)
        XCTAssertEqual([deep.focusMinutes, deep.shortBreakMinutes, deep.longBreakMinutes], [50, 10, 30])
        XCTAssertEqual(deep.roundsBeforeLongBreak, 5)
        XCTAssertTrue(deep.autoStartNext)
        let marathon = Preset.marathon.applied(to: base)
        XCTAssertEqual([marathon.focusMinutes, marathon.shortBreakMinutes], [90, 20])
    }

    func testCustomPresetLeavesConfigUntouched() {
        let base = TimerConfig(focusMinutes: 37, shortBreakMinutes: 3, longBreakMinutes: 11)
        XCTAssertEqual(Preset.custom.applied(to: base), base)
    }

    func testPresetDetection() {
        XCTAssertEqual(Preset.detect(TimerConfig()), .classic)
        XCTAssertEqual(Preset.detect(Preset.deep.applied(to: TimerConfig())), .deep)
        XCTAssertEqual(Preset.detect(TimerConfig(focusMinutes: 30)), .custom)
    }

    func testConfigCodableRoundTrip() throws {
        let cfg = TimerConfig(focusMinutes: 40, shortBreakMinutes: 8, longBreakMinutes: 20, roundsBeforeLongBreak: 3, autoStartNext: true)
        let data = try JSONEncoder().encode(cfg)
        XCTAssertEqual(try JSONDecoder().decode(TimerConfig.self, from: data), cfg)
    }

    func testLabelNormalization() {
        XCTAssertNil(FocusSession.normalize(nil))
        XCTAssertNil(FocusSession.normalize("   \n"))
        XCTAssertEqual(FocusSession.normalize("  寫作業 "), "寫作業")
        XCTAssertEqual(FocusSession.normalize(String(repeating: "a", count: 100))?.count, FocusSession.maxLabelLength)
    }
}
