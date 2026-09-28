import SwiftUI
import FocusCore

struct TimerTab: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Text(model.menuBarTitle)
                .font(.system(size: 52, weight: .light))
                .monospacedDigit()
                .accessibilityLabel("剩餘時間 \(model.menuBarTitle)")
            ProgressView(value: model.progress)
                .progressViewStyle(.linear)

            if model.phase == .focus {
                labelField
            }

            controls

            Divider()
            PresetSection()
        }
    }

    private var header: some View {
        HStack {
            Label(model.phase.title, systemImage: model.phase.symbol)
                .font(.headline)
            Spacer()
            Text("第 \(model.round) / \(model.config.roundsBeforeLongBreak) 輪")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var labelField: some View {
        HStack(spacing: 6) {
            TextField("正在做什麼（選填）", text: $model.label)
                .textFieldStyle(.roundedBorder)
            if !model.recentLabels.isEmpty {
                Menu {
                    ForEach(model.recentLabels, id: \.self) { l in
                        Button(l) { model.label = l }
                    }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("最近用過的標籤")
                .accessibilityLabel("最近用過的標籤")
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                model.toggle()
            } label: {
                Label(model.primaryButtonTitle, systemImage: model.isRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            Button {
                model.skip()
            } label: {
                Label("跳過", systemImage: "forward.end.fill")
            }
            .controlSize(.large)
            .help("跳到下一段（跳過的專注不會計入統計）")

            Button {
                model.reset()
            } label: {
                Label("重設", systemImage: "arrow.counterclockwise")
            }
            .controlSize(.large)
            .disabled(model.isIdle)
            .help("讓這一段回到尚未開始")
        }
        .labelStyle(.titleAndIcon)
    }
}

struct PresetSection: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("時間組合（專注/休息，分鐘）")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("時間組合", selection: Binding(get: { model.preset }, set: { model.choose(preset: $0) })) {
                ForEach(Preset.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if model.preset == .custom {
                VStack(spacing: 6) {
                    minuteStepper("專注", value: $model.config.focusMinutes)
                    minuteStepper("短休息", value: $model.config.shortBreakMinutes)
                    minuteStepper("長休息", value: $model.config.longBreakMinutes)
                    Stepper(value: $model.config.roundsBeforeLongBreak, in: TimerConfig.roundsRange) {
                        HStack {
                            Text("幾輪後長休息")
                            Spacer()
                            Text("\(model.config.roundsBeforeLongBreak) 輪").foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }

            Toggle("自動開始下一段", isOn: $model.config.autoStartNext)
                .toggleStyle(.checkbox)
        }
    }

    private func minuteStepper(_ title: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: TimerConfig.minuteRange) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue) 分鐘").foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }
}
