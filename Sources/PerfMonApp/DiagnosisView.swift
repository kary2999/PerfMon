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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🩺 诊断与建议").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("健康分 \(Metrics.healthScore(state.metrics))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.byLoad(100 - Metrics.healthScore(state.metrics)))
            }
            if issues.isEmpty {
                Text("✅ 当前没有发现明显问题，状态良好。")
                    .font(.system(size: 13)).foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 30)
            } else {
                ScrollView {
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
        }
        .padding(20)
        .frame(width: 480, height: 360)
    }
}
