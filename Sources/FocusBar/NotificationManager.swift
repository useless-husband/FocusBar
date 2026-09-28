import AppKit
import UserNotifications

/// 系統通知。UserNotifications 需要 App 有 bundle；
/// 用 `swift run` 直接跑執行檔時沒有 bundle，這裡會安靜地略過而不是當掉。
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleURL.pathExtension == "app" ? UNUserNotificationCenter.current() : nil
    }

    func prepare() {
        guard let center else { return }
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        guard let center else { return }
        center.requestAuthorization(options: [.alert]) { _, _ in }
    }

    func send(title: String, body: String) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }

    func playSound(named name: String) {
        let sound = NSSound(named: NSSound.Name(name)) ?? NSSound(named: NSSound.Name(AlertSound.fallback))
        sound?.play()
    }

    // 即使面板開著（App 算前景）也顯示橫幅。
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner]
    }
}
