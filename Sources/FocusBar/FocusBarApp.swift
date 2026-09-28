import SwiftUI
import FocusCore

@main
struct FocusBarApp: App {
    @StateObject private var model = AppModel()

    init() {
        // 用 swift run 直接執行時沒有 Info.plist，這裡確保同樣不出現在 Dock。
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environmentObject(model)
        } label: {
            MenuBarLabel()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)
    }
}

/// 選單列上的圖示與剩餘時間。數字用等寬，避免每秒寬度跳動。
struct MenuBarLabel: View {
    @EnvironmentObject var model: AppModel
    @AppStorage(PrefKey.showRemaining) private var showRemaining = true

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: model.menuBarSymbol)
            if showRemaining {
                Text(model.menuBarTitle)
                    .monospacedDigit()
            }
        }
    }
}
