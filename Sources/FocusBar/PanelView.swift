import SwiftUI
import FocusCore

enum PanelTab: String, CaseIterable, Identifiable {
    case timer = "計時"
    case stats = "統計"
    case settings = "設定"
    var id: String { rawValue }
}

struct PanelView: View {
    @EnvironmentObject var model: AppModel
    @State private var tab: PanelTab = .timer

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("檢視", selection: $tab) {
                ForEach(PanelTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if let notice = model.storageNotice {
                NoticeBanner(text: notice) { model.clearNotice() }
            }

            switch tab {
            case .timer: TimerTab()
            case .stats: StatsTab()
            case .settings: SettingsTab()
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

struct NoticeBanner: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("關閉提示")
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

extension Phase {
    var title: String {
        switch self {
        case .focus: return "專注"
        case .shortBreak: return "短休息"
        case .longBreak: return "長休息"
        }
    }

    var symbol: String {
        switch self {
        case .focus: return "timer"
        case .shortBreak, .longBreak: return "cup.and.saucer"
        }
    }
}
