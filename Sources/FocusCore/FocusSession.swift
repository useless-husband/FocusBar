import Foundation

/// 一段完整結束的專注紀錄。
///
/// 只存「結束時間 + 長度」，開始時間由 `endedAt - seconds` 推得。
public struct FocusSession: Codable, Equatable, Identifiable, Hashable {
    public var id: UUID
    public var endedAt: Date
    public var seconds: Int
    public var label: String?

    public init(id: UUID = UUID(), endedAt: Date, seconds: Int, label: String? = nil) {
        self.id = id
        self.endedAt = endedAt
        self.seconds = max(0, seconds)
        self.label = Self.normalize(label)
    }

    public var startedAt: Date { endedAt.addingTimeInterval(-TimeInterval(seconds)) }

    public static let maxLabelLength = 40

    /// 去掉前後空白、空字串視為沒有標籤、過長就截斷。
    public static func normalize(_ label: String?) -> String? {
        guard let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return String(trimmed.prefix(maxLabelLength))
    }
}
