import SwiftUI
import Charts
import FocusCore

struct StatsTab: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let today = model.today
        let days = model.lastSevenDays
        let labels = model.labelTotals

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 24) {
                figure(title: "今日專注", value: "\(Int(today.minutes.rounded()))", unit: "分鐘")
                figure(title: "完成輪數", value: "\(today.rounds)", unit: "輪")
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("最近 7 天（分鐘）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Chart(days) { d in
                    BarMark(x: .value("日期", d.day, unit: .day),
                            y: .value("專注分鐘", d.minutes))
                        .foregroundStyle(Calendar.current.isDateInToday(d.day)
                                         ? Color.accentColor : Color.accentColor.opacity(0.45))
                        .cornerRadius(2)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 120)
                .accessibilityLabel("最近 7 天專注分鐘數長條圖")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("依標籤（最近 7 天）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if labels.isEmpty {
                    Text("還沒有紀錄。完成一段專注後會出現在這裡。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(labels.prefix(6)) { item in
                        HStack {
                            Text(item.label ?? "未標記")
                                .foregroundStyle(item.label == nil ? .secondary : .primary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(item.minutes.rounded())) 分鐘 · \(item.rounds) 輪")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .font(.callout)
                    }
                }
            }
        }
    }

    private func figure(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 30, weight: .semibold)).monospacedDigit()
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }
}
