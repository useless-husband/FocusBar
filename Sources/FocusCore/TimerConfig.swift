import Foundation

public enum Phase: String, Codable, CaseIterable, Equatable {
    case focus
    case shortBreak
    case longBreak

    public var isBreak: Bool { self != .focus }
}

/// 計時設定。分鐘數與輪數都會被限制在合理範圍內。
public struct TimerConfig: Codable, Equatable {
    public var focusMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int
    /// 完成幾輪專注後進入長休息。
    public var roundsBeforeLongBreak: Int
    /// 一段結束後是否自動開始下一段。
    public var autoStartNext: Bool

    public static let minuteRange = 1...240
    public static let roundsRange = 2...12

    public init(focusMinutes: Int = 25,
                shortBreakMinutes: Int = 5,
                longBreakMinutes: Int = 15,
                roundsBeforeLongBreak: Int = 4,
                autoStartNext: Bool = false) {
        self.focusMinutes = focusMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.roundsBeforeLongBreak = roundsBeforeLongBreak
        self.autoStartNext = autoStartNext
    }

    public func duration(of phase: Phase) -> TimeInterval {
        let minutes: Int
        switch phase {
        case .focus: minutes = focusMinutes
        case .shortBreak: minutes = shortBreakMinutes
        case .longBreak: minutes = longBreakMinutes
        }
        return TimeInterval(minutes * 60)
    }

    /// 回傳數值被夾到合法範圍後的設定。
    public func validated() -> TimerConfig {
        var c = self
        c.focusMinutes = min(max(c.focusMinutes, Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
        c.shortBreakMinutes = min(max(c.shortBreakMinutes, Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
        c.longBreakMinutes = min(max(c.longBreakMinutes, Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
        c.roundsBeforeLongBreak = min(max(c.roundsBeforeLongBreak, Self.roundsRange.lowerBound), Self.roundsRange.upperBound)
        return c
    }
}

/// 預設組合。`custom` 沿用使用者自己設定的分鐘數。
public enum Preset: String, CaseIterable, Identifiable, Codable {
    case classic   // 25 / 5
    case deep      // 50 / 10
    case marathon  // 90 / 20
    case custom

    public var id: String { rawValue }

    /// 選單上顯示的簡短名稱。
    public var title: String {
        switch self {
        case .classic: return "25/5"
        case .deep: return "50/10"
        case .marathon: return "90/20"
        case .custom: return "自訂"
        }
    }

    /// (專注, 短休息, 長休息)；custom 回傳 nil。
    public var minutes: (focus: Int, short: Int, long: Int)? {
        switch self {
        case .classic: return (25, 5, 15)
        case .deep: return (50, 10, 30)
        case .marathon: return (90, 20, 30)
        case .custom: return nil
        }
    }

    /// 把預設組合套用到現有設定上（輪數與自動開始維持不變）。
    public func applied(to config: TimerConfig) -> TimerConfig {
        guard let m = minutes else { return config }
        var c = config
        c.focusMinutes = m.focus
        c.shortBreakMinutes = m.short
        c.longBreakMinutes = m.long
        return c
    }

    /// 由目前設定反推是哪個預設組合；都不吻合就是 custom。
    public static func detect(_ config: TimerConfig) -> Preset {
        for p in [Preset.classic, .deep, .marathon] {
            if let m = p.minutes,
               m.focus == config.focusMinutes,
               m.short == config.shortBreakMinutes,
               m.long == config.longBreakMinutes {
                return p
            }
        }
        return .custom
    }
}
