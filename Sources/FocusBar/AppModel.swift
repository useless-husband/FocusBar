import AppKit
import SwiftUI
import FocusCore

/// 把 FocusCore 的狀態機接到 UI：定時刷新、通知、存檔、快捷鍵。
@MainActor
final class AppModel: ObservableObject {
    // 計時狀態機是 struct，不直接 @Published（每次 tick 都會觸發重繪）。
    // 只在畫面上看得到的數字（整秒）或狀態改變時才通知 SwiftUI。
    private(set) var engine: TimerEngine

    @Published private(set) var remainingSeconds: Int
    @Published private(set) var sessions: [FocusSession] = []
    @Published private(set) var storageNotice: String?

    @Published var config: TimerConfig {
        didSet { configChanged() }
    }
    @Published var preset: Preset {
        didSet { UserDefaults.standard.set(preset.rawValue, forKey: PrefKey.preset) }
    }
    @Published var label: String {
        didSet {
            engine.label = label
            UserDefaults.standard.set(label, forKey: PrefKey.label)
        }
    }

    private let store = SessionStore()
    private var timer: Timer?
    private var hotKey: GlobalHotKey?
    private let stats = StatsCalculator()

    init() {
        let defaults = UserDefaults.standard
        let savedConfig = Self.loadConfig()
        var engine = TimerEngine(config: savedConfig)
        let savedLabel = defaults.string(forKey: PrefKey.label) ?? ""
        engine.label = savedLabel
        self.engine = engine
        self.config = engine.config
        self.label = savedLabel
        self.preset = Preset(rawValue: defaults.string(forKey: PrefKey.preset) ?? "") ?? Preset.detect(engine.config)
        self.remainingSeconds = Int(engine.remaining().rounded(.up))

        NotificationManager.shared.prepare()
        loadSessions()
        startTicking()
        observeWake()
        configureHotKey()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.configureHotKey() }
        }
    }

    // MARK: 顯示用

    var phase: Phase { engine.phase }
    var isRunning: Bool { engine.isRunning }
    var isIdle: Bool { engine.isIdle }
    var progress: Double { engine.progress }
    var round: Int { engine.currentRound }

    var menuBarTitle: String { TimeFormat.clock(TimeInterval(remainingSeconds)) }

    var menuBarSymbol: String {
        switch engine.phase {
        case .focus: return "timer"
        case .shortBreak, .longBreak: return "cup.and.saucer"
        }
    }

    var primaryButtonTitle: String {
        if engine.isRunning { return "暫停" }
        if engine.isPaused { return "繼續" }
        return "開始"
    }

    var recentLabels: [String] { stats.recentLabels(8, in: sessions) }
    var today: DayTotal { stats.total(on: Date(), in: sessions) }
    var lastSevenDays: [DayTotal] { stats.lastDays(7, endingAt: Date(), in: sessions) }
    var labelTotals: [LabelTotal] { stats.labelTotals(lastDays: 7, endingAt: Date(), in: sessions) }

    // MARK: 操作

    func toggle() {
        if engine.isIdle && engine.phase == .focus {
            NotificationManager.shared.requestAuthorizationIfNeeded()
        }
        engine.toggle()
        refresh(force: true)
    }

    func skip() { engine.skip(); refresh(force: true) }
    func reset() { engine.reset(); refresh(force: true) }
    func resetCycle() { engine.resetCycle(); refresh(force: true) }

    func choose(preset newPreset: Preset) {
        preset = newPreset
        config = newPreset.applied(to: config)
    }

    func clearNotice() { storageNotice = nil }

    func revealDataFolder() {
        try? FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(store.directory)
    }

    // MARK: 內部

    private func configChanged() {
        let valid = config.validated()
        if valid != config { config = valid; return }
        engine.apply(config: valid)
        if let data = try? JSONEncoder().encode(valid) {
            UserDefaults.standard.set(data, forKey: PrefKey.config)
        }
        refresh(force: true)
    }

    private static func loadConfig() -> TimerConfig {
        guard let data = UserDefaults.standard.data(forKey: PrefKey.config),
              let cfg = try? JSONDecoder().decode(TimerConfig.self, from: data) else { return TimerConfig() }
        return cfg.validated()
    }

    private func startTicking() {
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)   // 選單追蹤中也要持續更新
        timer = t
    }

    private func observeWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        if let done = engine.update() {
            handle(done)
            refresh(force: true)
        } else {
            refresh(force: false)
        }
    }

    private func refresh(force: Bool) {
        let secs = Int(engine.remaining().rounded(.up))
        if force { objectWillChange.send() }
        if secs != remainingSeconds { remainingSeconds = secs }
    }

    private func handle(_ done: PhaseCompletion) {
        let defaults = UserDefaults.standard
        if done.phase == .focus {
            let session = FocusSession(endedAt: Date(), seconds: Int(done.plannedSeconds), label: done.label)
            sessions.append(session)
            persist()
        }

        if defaults.object(forKey: PrefKey.notifications) as? Bool ?? true {
            let (title, body) = Self.message(for: done, config: engine.config)
            NotificationManager.shared.send(title: title, body: body)
        }
        if defaults.object(forKey: PrefKey.sound) as? Bool ?? true {
            NotificationManager.shared.playSound(named: defaults.string(forKey: PrefKey.soundName) ?? AlertSound.fallback)
        }
    }

    private static func message(for done: PhaseCompletion, config: TimerConfig) -> (String, String) {
        switch done.phase {
        case .focus:
            let next = done.nextPhase == .longBreak ? "長休息" : "短休息"
            let minutes = Int(config.duration(of: done.nextPhase) / 60)
            return ("專注結束", "第 \(done.round) 輪完成，休息 \(minutes) 分鐘（\(next)）。")
        case .shortBreak, .longBreak:
            return ("休息結束", "準備好就開始下一輪專注吧。")
        }
    }

    private func loadSessions() {
        let result = store.load()
        sessions = result.sessions
        switch result.recovery {
        case .none:
            break
        case .restoredFromPrevious(let backup):
            storageNotice = "紀錄檔損毀，已用上一份備份還原。損毀的檔案保留為 \(backup.lastPathComponent)。"
        case .startedFresh(let backup):
            storageNotice = "紀錄檔無法讀取，已重新建立。原檔保留為 \(backup.lastPathComponent)。"
        }
    }

    private func persist() {
        do {
            try store.save(sessions)
        } catch {
            storageNotice = "無法儲存專注紀錄：\(error.localizedDescription)"
        }
    }

    private func configureHotKey() {
        let enabled = UserDefaults.standard.object(forKey: PrefKey.hotKey) as? Bool ?? true
        if enabled {
            if hotKey == nil { hotKey = GlobalHotKey { [weak self] in Task { @MainActor in self?.toggle() } } }
            hotKey?.register()
        } else {
            hotKey?.unregister()
        }
    }
}
