import SwiftUI

struct HistoryView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("历史趋势 · 本次运行").font(.system(size: 14, weight: .semibold))
            Text("CPU 占用与 CPU 温度随时间变化（最多保留最近 \(max(state.cpuHistory.count, state.cpuTempHistory.count)) 个采样点）")
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))

            Theme.card(
                VStack(alignment: .leading, spacing: 6) {
                    Text("CPU 占用 %").font(.system(size: 11)).foregroundColor(.white.opacity(0.55))
                    SparklineView(points: state.cpuHistory, color: Theme.cool, maxValue: 100).frame(height: 40)
                }
            )
            Theme.card(
                VStack(alignment: .leading, spacing: 6) {
                    Text("CPU 温度 °C").font(.system(size: 11)).foregroundColor(.white.opacity(0.55))
                    if state.cpuTempHistory.isEmpty {
                        Text("温度不可用").font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
                            .frame(height: 40, alignment: .center).frame(maxWidth: .infinity)
                    } else {
                        SparklineView(points: state.cpuTempHistory, color: Theme.hot, maxValue: 100).frame(height: 40)
                    }
                }
            )
            HStack {
                Text("峰值 CPU \(Int(state.cpuHistory.max() ?? 0))%").font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                Spacer()
                if let mx = state.cpuTempHistory.max() {
                    Text("峰值温度 \(Int(mx))°C").font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                }
            }

            // CPU 超过 50% 的进程记录
            Text("CPU 超过 50% 的进程（单核占比）")
                .font(.system(size: 12, weight: .semibold)).padding(.top, 4)
            if state.highCPULog.isEmpty {
                Text("暂无记录——本次运行还没有进程 CPU 超过 50%。")
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.45))
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(state.highCPULog) { e in
                            HStack(spacing: 10) {
                                Text(Self.fmt.string(from: e.time))
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.white.opacity(0.5))
                                Text(e.name).font(.system(size: 12)).lineLimit(1)
                                Spacer()
                                Text("\(e.cpu)%").font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.hot)
                            }
                            .padding(.vertical, 6)
                            Divider().background(Color.white.opacity(0.06))
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 480, height: 372)
    }

    static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()
}
