import SwiftUI
import ServiceManagement

struct SettingsTab: View {
    @EnvironmentObject var model: AppModel
    @AppStorage(PrefKey.showRemaining) private var showRemaining = true
    @AppStorage(PrefKey.notifications) private var notifications = true
    @AppStorage(PrefKey.sound) private var sound = true
    @AppStorage(PrefKey.soundName) private var soundName = AlertSound.fallback
    @AppStorage(PrefKey.hotKey) private var hotKey = true

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            group("選單列") {
                Toggle("顯示剩餘時間（關閉則只顯示圖示）", isOn: $showRemaining)
            }

            group("提醒") {
                Toggle("階段結束時發送通知", isOn: $notifications)
                Toggle("播放提示音", isOn: $sound)
                if sound {
                    HStack {
                        Picker("音效", selection: $soundName) {
                            ForEach(AlertSound.names, id: \.self) { Text($0).tag($0) }
                        }
                        Button {
                            NotificationManager.shared.playSound(named: soundName)
                        } label: {
                            Image(systemName: "speaker.wave.2")
                        }
                        .help("試聽")
                        .accessibilityLabel("試聽提示音")
                    }
                }
            }

            group("一般") {
                Toggle("開機時自動啟動", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                if let launchError {
                    Text(launchError).font(.callout).foregroundStyle(.red)
                }
                Toggle("啟用全域快捷鍵 ⌃⌥⌘F（開始/暫停）", isOn: $hotKey)
            }

            group("資料") {
                HStack {
                    Button("在 Finder 顯示紀錄檔") { model.revealDataFolder() }
                    Button("從第 1 輪重新開始") { model.resetCycle() }
                }
            }

            Divider()
            HStack {
                Text("FocusBar \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "開發版")")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                Spacer()
                Button("結束 FocusBar") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .toggleStyle(.checkbox)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            content()
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        launchError = nil
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            launchError = "無法變更開機啟動：\(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
