import Foundation

/// 單調時鐘：回傳「自某個起點以來的秒數」。
///
/// 計時狀態機只依賴這個協定，不讀牆上時間（Date），
/// 所以使用者改系統時間不會影響倒數；測試時也能注入假時鐘快轉。
public protocol TimeSource {
    func now() -> TimeInterval
}

/// 以 `ContinuousClock` 實作。ContinuousClock 在電腦睡眠期間仍會繼續走，
/// 因此睡醒後「結束時間戳 - 現在」自然就是正確的剩餘時間。
public struct SystemTimeSource: TimeSource {
    private let origin = ContinuousClock.now

    public init() {}

    public func now() -> TimeInterval {
        let d = origin.duration(to: ContinuousClock.now)
        return Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
    }
}

public enum TimeFormat {
    /// 把秒數格式化為 "24:13"（向上取整，讓 0:00 只在真的結束時出現）。
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
