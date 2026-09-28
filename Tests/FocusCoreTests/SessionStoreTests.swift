import XCTest
@testable import FocusCore

final class SessionStoreTests: XCTestCase {
    var dir: URL!
    var store: SessionStore!

    override func setUp() {
        dir = makeTempDirectory().appendingPathComponent("FocusBar")   // 尚不存在，測試自動建立
        store = SessionStore(directory: dir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir.deletingLastPathComponent())
    }

    func sample(_ n: Int) -> [FocusSession] {
        (0..<n).map { FocusSession(endedAt: date(2026, 5, 1, 9 + $0), seconds: 1500, label: $0 % 2 == 0 ? "A" : nil) }
    }

    func files() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).sorted()
    }

    func testMissingFileLoadsEmpty() {
        let r = store.load()
        XCTAssertEqual(r.sessions, [])
        XCTAssertEqual(r.recovery, .none)
        XCTAssertFalse(r.migratedFromV1)
    }

    func testSaveCreatesDirectoryAndRoundTrips() throws {
        let s = sample(3)
        try store.save(s)
        XCTAssertEqual(store.load().sessions, s)
    }

    func testAtomicWriteLeavesNoTemporaryFiles() throws {
        try store.save(sample(2))
        try store.save(sample(4))
        XCTAssertEqual(files(), ["sessions.json", "sessions.previous.json"])
    }

    func testOverwriteKeepsPreviousGoodVersion() throws {
        try store.save(sample(2))
        try store.save(sample(5))
        let prev = try Data(contentsOf: store.previousURL)
        XCTAssertEqual(SessionStore.parse(prev)?.sessions.count, 2)
    }

    func testFileContainsVersionField() throws {
        try store.save(sample(1))
        let obj = try JSONSerialization.jsonObject(with: Data(contentsOf: store.fileURL)) as? [String: Any]
        XCTAssertEqual(obj?["version"] as? Int, 2)
    }

    func testCorruptFileWithoutPreviousStartsFreshAndKeepsBackup() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{ this is not json".utf8).write(to: store.fileURL)
        let r = store.load(now: date(2026, 5, 1, 12))
        XCTAssertEqual(r.sessions, [])
        guard case .startedFresh(let backup) = r.recovery else { return XCTFail("expected startedFresh") }
        XCTAssertEqual(try String(contentsOf: backup, encoding: .utf8), "{ this is not json")
        XCTAssertTrue(backup.lastPathComponent.hasPrefix("sessions.corrupt-20260501-120000"))
        // 重建後的新檔可正常使用
        XCTAssertEqual(store.load().recovery, .none)
        try store.save(sample(1))
        XCTAssertEqual(store.load().sessions.count, 1)
    }

    func testCorruptFileRestoresFromPrevious() throws {
        let good = sample(2)
        try store.save(good)
        try store.save(sample(3))
        try Data([0xFF, 0x00, 0x12]).write(to: store.fileURL)      // 弄壞主檔
        let r = store.load()
        XCTAssertEqual(r.sessions, good)
        guard case .restoredFromPrevious = r.recovery else { return XCTFail("expected restore") }
        XCTAssertEqual(store.load().sessions, good, "還原後主檔已修好")
        XCTAssertTrue(files().contains { $0.hasPrefix("sessions.corrupt-") })
    }

    func testRepeatedCorruptionDoesNotOverwriteEarlierBackups() throws {
        let now = date(2026, 5, 1, 12)
        for _ in 0..<2 {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data("bad".utf8).write(to: store.fileURL)
            _ = store.load(now: now)
        }
        XCTAssertEqual(files().filter { $0.hasPrefix("sessions.corrupt-") }.count, 2)
    }

    func testEmptyFileIsTreatedAsCorrupt() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data().write(to: store.fileURL)
        guard case .startedFresh = store.load().recovery else { return XCTFail() }
    }

    func testNewerVersionIsBackedUpNotSilentlyDiscarded() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(#"{"version": 99, "sessions": []}"#.utf8).write(to: store.fileURL)
        let r = store.load()
        guard case .startedFresh(let backup) = r.recovery else { return XCTFail() }
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
    }

    func testMigratesV1ArrayFormat() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let v1 = """
        [
          {"finishedAt": "2026-05-01T09:25:00Z", "minutes": 25, "tag": "英文"},
          {"finishedAt": "2026-05-01T10:15:00Z", "minutes": 50}
        ]
        """
        try Data(v1.utf8).write(to: store.fileURL)
        let r = store.load()
        XCTAssertTrue(r.migratedFromV1)
        XCTAssertEqual(r.recovery, .none)
        XCTAssertEqual(r.sessions.count, 2)
        XCTAssertEqual(r.sessions[0].seconds, 1500)
        XCTAssertEqual(r.sessions[0].label, "英文")
        XCTAssertEqual(r.sessions[0].endedAt, date(2026, 5, 1, 9, 25))
        XCTAssertNil(r.sessions[1].label)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.legacyBackupURL.path), "舊檔保留備份")
        // 第二次讀取已是新格式
        let again = store.load()
        XCTAssertFalse(again.migratedFromV1)
        XCTAssertEqual(again.sessions.map(\.seconds), [1500, 3000])
    }

    func testDefaultDirectoryIsUnderApplicationSupport() {
        let p = SessionStore.defaultDirectory().path
        XCTAssertTrue(p.hasSuffix("Library/Application Support/FocusBar"))
    }
}
