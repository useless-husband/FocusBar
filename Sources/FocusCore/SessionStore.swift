import Foundation

/// 目前（第 2 版）的檔案格式。
struct SessionLog: Codable {
    static let currentVersion = 2
    var version: Int
    var sessions: [FocusSession]
}

/// 第 1 版是一個沒有 version 欄位的純陣列，時間用 ISO 8601 字串、長度用分鐘。
struct LegacyRecord: Codable {
    var finishedAt: Date
    var minutes: Int
    var tag: String?
}

/// 專注紀錄的 JSON 存取。
///
/// - 寫入用 `Data.write(options: .atomic)`（先寫暫存檔再 rename），不會留下寫到一半的檔案。
/// - 每次覆寫前，把舊檔複製成 `sessions.previous.json`。
/// - 讀到壞檔：先把壞檔改名成 `sessions.corrupt-時間.json` 保留，
///   再嘗試從 previous 還原，還是不行才用空紀錄重建。
public struct SessionStore {
    public enum Recovery: Equatable {
        case none
        /// 壞檔已備份，內容由上一份好檔還原。
        case restoredFromPrevious(backup: URL)
        /// 壞檔已備份，重新建立空檔。
        case startedFresh(backup: URL)
    }

    public struct LoadResult: Equatable {
        public var sessions: [FocusSession]
        public var recovery: Recovery
        /// 是否從舊格式轉換而來。
        public var migratedFromV1: Bool
    }

    public let directory: URL
    public var fileURL: URL { directory.appendingPathComponent("sessions.json") }
    public var previousURL: URL { directory.appendingPathComponent("sessions.previous.json") }
    public var legacyBackupURL: URL { directory.appendingPathComponent("sessions.v1.backup.json") }

    public init(directory: URL = SessionStore.defaultDirectory()) {
        self.directory = directory
    }

    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("FocusBar", isDirectory: true)
    }

    // MARK: 讀

    public func load(now: Date = Date()) -> LoadResult {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            return LoadResult(sessions: [], recovery: .none, migratedFromV1: false)
        }
        if let data = try? Data(contentsOf: fileURL), let parsed = Self.parse(data) {
            if parsed.migrated {
                // 舊格式：保留原檔一份，再寫成新格式。
                try? fm.removeItem(at: legacyBackupURL)
                try? fm.copyItem(at: fileURL, to: legacyBackupURL)
                try? save(parsed.sessions)
            }
            return LoadResult(sessions: parsed.sessions, recovery: .none, migratedFromV1: parsed.migrated)
        }

        // 壞檔（或版本比程式新，無法安全讀取）：備份後復原。
        let backup = uniqueCorruptURL(now: now)
        try? fm.moveItem(at: fileURL, to: backup)

        if let data = try? Data(contentsOf: previousURL), let parsed = Self.parse(data) {
            try? save(parsed.sessions)
            return LoadResult(sessions: parsed.sessions, recovery: .restoredFromPrevious(backup: backup), migratedFromV1: false)
        }
        try? save([])
        return LoadResult(sessions: [], recovery: .startedFresh(backup: backup), migratedFromV1: false)
    }

    // MARK: 寫

    public func save(_ sessions: [FocusSession]) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(SessionLog(version: SessionLog.currentVersion, sessions: sessions))

        if fm.fileExists(atPath: fileURL.path), let old = try? Data(contentsOf: fileURL), Self.parse(old) != nil {
            try? old.write(to: previousURL, options: .atomic)
        }
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: 內部

    static func parse(_ data: Data) -> (sessions: [FocusSession], migrated: Bool)? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let log = try? decoder.decode(SessionLog.self, from: data) {
            guard log.version <= SessionLog.currentVersion else { return nil }
            return (log.sessions, false)
        }
        if let legacy = try? decoder.decode([LegacyRecord].self, from: data) {
            let converted = legacy.map {
                FocusSession(endedAt: $0.finishedAt, seconds: $0.minutes * 60, label: $0.tag)
            }
            return (converted, true)
        }
        return nil
    }

    private func uniqueCorruptURL(now: Date) -> URL {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = f.string(from: now)
        var url = directory.appendingPathComponent("sessions.corrupt-\(stamp).json")
        var n = 1
        while FileManager.default.fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("sessions.corrupt-\(stamp)-\(n).json")
            n += 1
        }
        return url
    }
}
