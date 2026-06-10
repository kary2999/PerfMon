import SwiftUI
import SensorKit

struct DiagnosisView: View {
    @ObservedObject var state: AppState

    private var issues: [Issue] { DiagnosisEngine.analyze(state.metrics) }

    private func color(_ s: IssueSeverity) -> Color {
        switch s {
        case .critical: return Theme.hot
        case .warning: return Theme.warm
        case .info: return Theme.cool
        }
    }
    private func icon(_ s: IssueSeverity) -> String {
        switch s {
        case .critical: return "🔴"
        case .warning: return "🟠"
        case .info: return "🔵"
        }
    }

    private var swapGrowth: Double {
        SwapTrend.growthPerMinute(state.swapHistory, sampleIntervalSec: state.slowIntervalSec)
    }
    private var swapDir: SwapTrend.Direction { SwapTrend.direction(growthPerMin: swapGrowth) }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🩺 诊断与建议").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("健康分 \(Metrics.healthScore(state.metrics))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.byLoad(100 - Metrics.healthScore(state.metrics)))
            }

            swapAnalysisCard
            if issues.isEmpty {
                Text("✅ 当前没有发现明显问题，状态良好。")
                    .font(.system(size: 13)).foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 30)
            } else {
                VStack(spacing: 9) {
                    ForEach(issues) { issue in
                        HStack(alignment: .top, spacing: 11) {
                            Text(icon(issue.severity)).font(.system(size: 15))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(issue.title).font(.system(size: 13, weight: .semibold))
                                Text(issue.detail).font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(color(issue.severity).opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(color(issue.severity).opacity(0.3), lineWidth: 1))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding(20)
        }
        .frame(width: 480, height: 400)
    }

    // Swap 分析卡
    private var swapAnalysisCard: some View {
        let dirColor: Color = swapDir == .rising ? Theme.hot : (swapDir == .falling ? Theme.good : Theme.cool)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("💾 Swap 分析").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(String(format: "%.1f GB", state.metrics.swapUsedGB))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            HStack(spacing: 6) {
                Text("增长趋势").font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                Text(swapDir.rawValue).font(.system(size: 11, weight: .bold)).foregroundColor(dirColor)
                if swapDir != .stable {
                    Text(String(format: "%+.1f GB/分钟", swapGrowth))
                        .font(.system(size: 11, design: .monospaced)).foregroundColor(dirColor)
                }
            }
            Text("最可能的来源（按内存占用推断）").font(.system(size: 10)).foregroundColor(.white.opacity(0.45))
            ForEach(state.metrics.topMemProcesses.prefix(3), id: \.pid) { p in
                HStack(spacing: 8) {
                    Circle().fill(Theme.warm).frame(width: 6, height: 6)
                    Text(p.name).font(.system(size: 12)).lineLimit(1)
                    Spacer()
                    Text(p.memMB >= 1024 ? String(format: "%.1fG", Double(p.memMB)/1024) : "\(p.memMB)M")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.white.opacity(0.8))
                }
            }
            Text("说明：macOS 不公开每个进程的 swap 用量，以上按内存占用推断。关闭大内存应用可降低压力、让 swap 逐步回落；swap 只有重启才会清零。")
                .font(.system(size: 10)).foregroundColor(.white.opacity(0.5)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07)).cornerRadius(12)
    }
}
