import SwiftUI
import SensorKit

struct BoostView: View {
    @ObservedObject var state: AppState
    @State private var selected: Set<BoostAction> = []
    @State private var running = false
    @State private var results: [BoostStepResult] = []
    @State private var initialized = false

    private func gain(_ a: BoostAction) -> (String, Color) {
        switch a {
        case .purgeMemory: return ("释放内存", Theme.good)
        case .killProcesses: return ("降 CPU", Theme.warm)
        case .clearCaches: return ("清磁盘", Theme.good)
        case .reduceEffects: return ("WindowServer↓", Theme.good)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("⚡ 一键加速").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("勾选要执行的项").font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
            }

            ForEach(BoostAction.allCases, id: \.self) { action in
                let g = gain(action)
                HStack(spacing: 11) {
                    Image(systemName: selected.contains(action) ? "checkmark.square.fill" : "square")
                        .foregroundColor(selected.contains(action) ? Theme.cool : .white.opacity(0.4))
                        .onTapGesture {
                            if selected.contains(action) { selected.remove(action) } else { selected.insert(action) }
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.title).font(.system(size: 13, weight: .medium))
                        Text(action.command).font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    Text(g.0).font(.system(size: 12, weight: .bold)).foregroundColor(g.1)
                    if action.isRisky {
                        tag("有风险", Theme.warm)
                    } else if action.isReversible {
                        tag("可逆", Theme.good)
                    }
                }
                .padding(11)
                .background(Color.white.opacity(0.07)).cornerRadius(11)
            }

            HStack {
                Text(running ? "执行中…" : "\(selected.count) 项已选 · 含密码/风险项会确认")
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                Spacer()
                Button(running ? "执行中" : "执行优化") { runBoost() }
                    .disabled(running || selected.isEmpty)
                    .buttonStyle(.borderedProminent)
            }

            if !results.isEmpty {
                Theme.card(
                    VStack(alignment: .leading, spacing: 4) {
                        Text("执行结果").font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                        ForEach(results.indices, id: \.self) { i in
                            HStack(spacing: 6) {
                                Text(results[i].ok ? "✓" : "–").foregroundColor(results[i].ok ? Theme.good : Theme.warm)
                                Text("\(results[i].action.title)：\(results[i].message)")
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.white.opacity(0.75))
                            }
                        }
                    }
                )
            }
        }
        .padding(20)
        .frame(width: 480, height: 360)
        .onAppear {
            if !initialized {
                selected = Set(OptimizationService.suggestedActions(state.metrics))
                initialized = true
            }
        }
    }

    private func tag(_ t: String, _ c: Color) -> some View {
        Text(t).font(.system(size: 10)).padding(.horizontal, 7).padding(.vertical, 2)
            .overlay(Capsule().stroke(c.opacity(0.5), lineWidth: 1)).foregroundColor(c)
    }

    private func runBoost() {
        running = true
        results = []
        let pids = state.metrics.topProcesses.prefix(2).map { $0.pid }
        let chosen = BoostAction.allCases.filter { selected.contains($0) }
        DispatchQueue.global().async {
            var acc: [BoostStepResult] = []
            for a in chosen {
                acc.append(state.boost.execute(a, killPids: pids))
            }
            DispatchQueue.main.async {
                results = acc
                running = false
            }
        }
    }
}
