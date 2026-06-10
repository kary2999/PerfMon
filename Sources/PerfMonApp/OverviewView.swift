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
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                RocketLogo(size: 18)
                Text("PerfMon").font(.system(size: 15, weight: .semibold))
                Text("v\(AppInfo.version)").font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
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
                SparklineView(points: state.cpuHistory, color: cpuColor).frame(height: 44)
            }.padding(12).background(Color.white.opacity(0.07)).cornerRadius(12)

            // 内存占用详情
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("内存占用详情").font(.system(size: 11)).foregroundColor(.white.opacity(0.55))
                    Spacer()
                    Text(String(format: "%.1f / %.1f GB", state.metrics.memUsedGB, state.metrics.memTotalGB))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                HStack(spacing: 14) {
                    memItem("应用", state.metrics.memAppGB, Theme.cool)
                    memItem("系统驻留", state.metrics.memWiredGB, Theme.warm)
                    memItem("压缩", state.metrics.memCompressedGB, Theme.hot)
                }
                Divider().background(Color.white.opacity(0.08)).padding(.vertical, 2)
                Text("占用最多的应用").font(.system(size: 10)).foregroundColor(.white.opacity(0.45))
                ForEach(state.metrics.topMemProcesses.prefix(5), id: \.pid) { p in
                    HStack(spacing: 8) {
                        Circle().fill(Theme.warm).frame(width: 6, height: 6)
                        Text(p.name).font(.system(size: 12)).lineLimit(1)
                        Spacer()
                        Text(fmtMem(p.memMB))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                if state.metrics.topMemProcesses.isEmpty {
                    Text("采样中…").font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                }
            }.padding(12).background(Color.white.opacity(0.07)).cornerRadius(12)
            HStack(spacing: 18) {
                stat("内存压力", state.metrics.pressure.label, pressureColor)
                stat("内存", "\(state.metrics.memPercent)%")
                stat("Swap", "\(state.metrics.swapPercent)%")
                stat("负载", String(format: "%.2f", state.metrics.load1))
                stat("开机", "\(state.metrics.uptimeDays)天")
            }
        }
        .padding(20)
        }
        .frame(width: 480, height: 400)
    }

    private var pressureColor: Color {
        switch state.metrics.pressure {
        case .normal: return Theme.good
        case .warning: return Theme.warm
        case .critical: return Theme.hot
        }
    }

    private func fmtMem(_ mb: Int) -> String {
        mb >= 1024 ? String(format: "%.1fG", Double(mb) / 1024) : "\(mb)M"
    }

    private func memItem(_ k: String, _ gb: Double, _ c: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(c).frame(width: 7, height: 7)
            Text(k).font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
            Text(String(format: "%.1fG", gb)).font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
    }

    private func stat(_ k: String, _ v: String, _ color: Color = .white) -> some View {
        VStack(spacing: 3) {
            Text(k).font(.system(size: 10)).foregroundColor(.white.opacity(0.55))
            Text(v).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(color)
        }
    }
}
