import Foundation

/// UserDefaults 的鍵名。
enum PrefKey {
    static let showRemaining = "showRemainingInMenuBar"
    static let notifications = "notificationsEnabled"
    static let sound = "soundEnabled"
    static let soundName = "soundName"
    static let hotKey = "globalHotKeyEnabled"
    static let config = "timerConfig"
    static let preset = "timerPreset"
    static let label = "lastLabel"
}

/// 可選的系統提示音（macOS 內建，位於 /System/Library/Sounds）。
enum AlertSound {
    static let names = ["Glass", "Ping", "Hero", "Submarine", "Funk", "Tink"]
    static let fallback = "Glass"
}
