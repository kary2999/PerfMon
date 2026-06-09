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
                    SparklineView(points: state.cpuHistory, color: Theme.cool, maxValue: 100).frame(height: 90)
                }
            )
            Theme.card(
                VStack(alignment: .leading, spacing: 6) {
                    Text("CPU 温度 °C").font(.system(size: 11)).foregroundColor(.white.opacity(0.55))
                    if state.cpuTempHistory.isEmpty {
                        Text("温度不可用").font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
                            .frame(height: 90, alignment: .center).frame(maxWidth: .infinity)
                    } else {
                        SparklineView(points: state.cpuTempHistory, color: Theme.hot, maxValue: 100).frame(height: 90)
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
        }
        .padding(20)
        .frame(width: 480, height: 360)
    }
}
