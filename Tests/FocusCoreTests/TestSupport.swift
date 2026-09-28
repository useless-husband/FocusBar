import Foundation
@testable import FocusCore

/// 可手動快轉的假時鐘。
final class ManualTimeSource: TimeSource {
    var current: TimeInterval
    init(_ start: TimeInterval = 1000) { current = start }
    func now() -> TimeInterval { current }
    func advance(_ seconds: TimeInterval) { current += seconds }
}

func makeEngine(_ config: TimerConfig = TimerConfig(), clock: ManualTimeSource = ManualTimeSource()) -> (TimerEngine, ManualTimeSource) {
    (TimerEngine(config: config, clock: clock), clock)
}

/// 固定在 UTC 的日曆，讓日期計算不受測試機器時區影響。
func utcCalendar() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}

func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, _ s: Int = 0, calendar: Calendar = utcCalendar()) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
}

func makeTempDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("FocusBarTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
