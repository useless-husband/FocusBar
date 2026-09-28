import Foundation

public struct DayTotal: Equatable, Identifiable {
    /// 當天 00:00（依傳入的 Calendar 與時區）。
    public let day: Date
    public let seconds: TimeInterval
    public let rounds: Int
    public var id: Date { day }
    public var minutes: Double { seconds / 60 }
}

public struct LabelTotal: Equatable, Identifiable {
    /// nil 代表沒有加標籤。
    public let label: String?
    public let seconds: TimeInterval
    public let rounds: Int
    public var id: String { label ?? "\u{0}unlabeled" }
    public var minutes: Double { seconds / 60 }
}

/// 統計彙總。日界線由注入的 Calendar 決定，方便測試不同時區。
///
/// 一段專注若橫跨午夜，時間會依實際重疊長度分到兩天；
/// 「完成輪數」則算在結束的那一天。
public struct StatsCalculator {
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func total(on date: Date, in sessions: [FocusSession]) -> DayTotal {
        let start = calendar.startOfDay(for: date)
        return dayTotal(start: start, sessions: sessions)
    }

    /// 最近 n 天（含 `now` 當天），由舊到新，沒有紀錄的日子也會出現（0）。
    public func lastDays(_ n: Int, endingAt now: Date, in sessions: [FocusSession]) -> [DayTotal] {
        guard n > 0 else { return [] }
        let today = calendar.startOfDay(for: now)
        return (0..<n).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return dayTotal(start: day, sessions: sessions)
        }
    }

    /// 最近 n 天各標籤的總和，專注時間多的排前面。
    public func labelTotals(lastDays n: Int, endingAt now: Date, in sessions: [FocusSession]) -> [LabelTotal] {
        guard n > 0 else { return [] }
        let today = calendar.startOfDay(for: now)
        guard let first = calendar.date(byAdding: .day, value: -(n - 1), to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        var seconds: [String?: TimeInterval] = [:]
        var rounds: [String?: Int] = [:]
        for s in sessions {
            let key = s.label
            let overlap = Self.overlap(of: s, with: first..<end)
            if overlap > 0 { seconds[key, default: 0] += overlap }
            if s.endedAt >= first && s.endedAt < end { rounds[key, default: 0] += 1 }
        }
        let keys = Set(seconds.keys).union(rounds.keys)
        return keys.map { LabelTotal(label: $0, seconds: seconds[$0] ?? 0, rounds: rounds[$0] ?? 0) }
            .sorted {
                if $0.seconds != $1.seconds { return $0.seconds > $1.seconds }
                return ($0.label ?? "") < ($1.label ?? "")
            }
    }

    /// 最近用過的標籤（新到舊、不重複）。
    public func recentLabels(_ limit: Int, in sessions: [FocusSession]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for s in sessions.sorted(by: { $0.endedAt > $1.endedAt }) {
            guard let l = s.label, seen.insert(l).inserted else { continue }
            result.append(l)
            if result.count >= limit { break }
        }
        return result
    }

    // MARK: 內部

    private func dayTotal(start: Date, sessions: [FocusSession]) -> DayTotal {
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return DayTotal(day: start, seconds: 0, rounds: 0)
        }
        var seconds: TimeInterval = 0
        var rounds = 0
        for s in sessions {
            seconds += Self.overlap(of: s, with: start..<end)
            if s.endedAt >= start && s.endedAt < end { rounds += 1 }
        }
        return DayTotal(day: start, seconds: seconds, rounds: rounds)
    }

    private static func overlap(of session: FocusSession, with range: Range<Date>) -> TimeInterval {
        let lo = max(session.startedAt, range.lowerBound)
        let hi = min(session.endedAt, range.upperBound)
        return max(0, hi.timeIntervalSince(lo))
    }
}
