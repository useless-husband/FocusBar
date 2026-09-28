import Foundation

public enum RunState: Equatable {
    case idle
    /// 執行中，記錄的是「單調時鐘上的結束時間點」，不是剩餘秒數。
    case running(endsAt: TimeInterval)
    case paused(remaining: TimeInterval)
}

/// 一段計時自然結束時的事件。
public struct PhaseCompletion: Equatable {
    public let phase: Phase
    public let plannedSeconds: TimeInterval
    public let label: String?
    /// 剛結束的是第幾輪專注（休息結束時為該休息前的那一輪）。
    public let round: Int
    public let nextPhase: Phase
    public let autoStarted: Bool
}

/// 番茄鐘狀態機。
///
/// - 所有時間計算都用「結束時間戳」：`remaining = endsAt - clock.now()`，
///   不累加 tick，所以睡眠、App 卡頓、呼叫頻率不影響準確度。
/// - 型別是 struct，沒有任何 UI 依賴，時鐘由外部注入。
public struct TimerEngine {
    public private(set) var config: TimerConfig
    public private(set) var phase: Phase = .focus
    public private(set) var state: RunState = .idle
    /// 目前這個循環已完成的專注輪數（0 ..< roundsBeforeLongBreak）。
    public private(set) var completedFocusRounds: Int = 0
    /// 目前專注要記到哪個標籤；在專注結束時取值。
    public var label: String?

    private let clock: any TimeSource

    public init(config: TimerConfig = TimerConfig(), clock: any TimeSource = SystemTimeSource()) {
        self.config = config.validated()
        self.clock = clock
    }

    // MARK: 查詢

    public var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    public var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    public var isIdle: Bool { state == .idle }

    public var phaseDuration: TimeInterval { config.duration(of: phase) }

    public func remaining() -> TimeInterval {
        switch state {
        case .idle: return phaseDuration
        case .running(let endsAt): return max(0, endsAt - clock.now())
        case .paused(let remaining): return remaining
        }
    }

    /// 已經走過的比例，0...1。
    public var progress: Double {
        let total = phaseDuration
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining() / total))
    }

    /// 顯示用的輪次（1 起算）。
    public var currentRound: Int {
        switch phase {
        case .focus: return completedFocusRounds + 1
        case .shortBreak, .longBreak: return max(1, completedFocusRounds)
        }
    }

    // MARK: 操作

    /// 閒置時開始整段；暫停時繼續；執行中不動作。
    public mutating func start() {
        switch state {
        case .idle:
            state = .running(endsAt: clock.now() + phaseDuration)
        case .paused(let remaining):
            state = .running(endsAt: clock.now() + remaining)
        case .running:
            break
        }
    }

    public mutating func pause() {
        guard case .running(let endsAt) = state else { return }
        state = .paused(remaining: max(0, endsAt - clock.now()))
    }

    /// 執行中 → 暫停；其他狀態 → 開始／繼續。
    public mutating func toggle() {
        if isRunning { pause() } else { start() }
    }

    /// 把目前這一段回到尚未開始的狀態（階段與輪次不變）。
    public mutating func reset() {
        state = .idle
    }

    /// 整個循環從「專注 第 1 輪」重來。
    public mutating func resetCycle() {
        state = .idle
        phase = .focus
        completedFocusRounds = 0
    }

    /// 跳到下一段。跳過專注不算完成，輪次不會增加。
    /// 若跳過前正在執行且設定了自動開始，下一段會直接開始。
    public mutating func skip() {
        let wasRunning = isRunning
        advance(countingFocus: false)
        state = (wasRunning && config.autoStartNext) ? .running(endsAt: clock.now() + phaseDuration) : .idle
    }

    /// 檢查是否已到時間。App 只要定期呼叫即可；即使很久沒呼叫（例如睡眠後）
    /// 也只會結束一次，下一段從「現在」起算，不會連鎖觸發。
    @discardableResult
    public mutating func update() -> PhaseCompletion? {
        guard case .running(let endsAt) = state else { return nil }
        let now = clock.now()
        guard now >= endsAt else { return nil }

        let finished = phase
        let planned = phaseDuration
        let labelAtEnd = finished == .focus ? label : nil
        let roundAtEnd = currentRound

        advance(countingFocus: true)
        let auto = config.autoStartNext
        state = auto ? .running(endsAt: now + phaseDuration) : .idle

        return PhaseCompletion(phase: finished,
                               plannedSeconds: planned,
                               label: labelAtEnd,
                               round: roundAtEnd,
                               nextPhase: phase,
                               autoStarted: auto)
    }

    /// 更換設定。執行中的這一段維持原本的結束時間，下一段才會採用新數值。
    public mutating func apply(config newConfig: TimerConfig) {
        config = newConfig.validated()
        if completedFocusRounds >= config.roundsBeforeLongBreak && phase == .focus {
            completedFocusRounds = 0
        }
    }

    // MARK: 內部

    private mutating func advance(countingFocus: Bool) {
        switch phase {
        case .focus:
            if countingFocus {
                completedFocusRounds += 1
                phase = completedFocusRounds >= config.roundsBeforeLongBreak ? .longBreak : .shortBreak
            } else {
                phase = .shortBreak
            }
        case .shortBreak:
            phase = .focus
        case .longBreak:
            completedFocusRounds = 0
            phase = .focus
        }
    }
}
