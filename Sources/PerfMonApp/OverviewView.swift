import SwiftUI
import SensorKit

struct OverviewView: View {
    @ObservedObject var state: AppState

    private var cpuColor: Color {
        let p = state.metrics.cpuPercent
        if p >= 80 { return Color(red: 1, green: 0.37, blue: 0.31) }
        if p >= 50 { return Color(red: 1, green: 0.83, blue: 0.47) }
        return Color(red: 0.48, green: 0.94, blue: 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🚀 PerfMon").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("健康分 \(Metrics.healthScore(state.metrics))")
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
            }
            HStack(spacing: 14) {
                RingView(value: Double(state.metrics.cpuPercent), label: "CPU", unit: "%", color: cpuColor)
                TempGaugeView(title: "CPU 温度", value: state.metrics.temps.cpu, history: state.cpuTempHistory)
                TempGaugeView(title: "GPU 温度", value: state.metrics.temps.gpu, history: [])
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("CPU 负载趋势 · 最近 60s").font(.system(size: 11)).foregroundColor(.white.opacity(0.55))
                SparklineView(points: state.cpuHistory, color: cpuColor).frame(height: 60)
            }.padding(12).background(Color.white.opacity(0.07)).cornerRadius(12)
            HStack(spacing: 20) {
                stat("内存", "\(state.metrics.memPercent)%")
                stat("Swap", "\(state.metrics.swapPercent)%")
                stat("负载", String(format: "%.2f", state.metrics.load1))
                stat("开机", "\(state.metrics.uptimeDays) 天")
            }
        }
        .padding(20)
        .frame(width: 480, height: 360)
    }

    private func stat(_ k: String, _ v: String) -> some View {
        VStack(spacing: 3) {
            Text(k).font(.system(size: 10)).foregroundColor(.white.opacity(0.55))
            Text(v).font(.system(size: 13, weight: .bold, design: .monospaced))
        }
    }
}
