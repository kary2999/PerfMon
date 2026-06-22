import SwiftUI
import SensorKit

/// 选择性释放内存：列出可关闭的第三方应用（按内存排序，标注空闲/活跃），
/// 用户勾选后优雅退出以释放 RAM。系统进程已排除、不需密码。
struct ReleaseMemoryView: View {
    @ObservedObject var state: AppState
    var onClose: () -> Void
    @State private var selected: Set<Int> = []
    @State private var releasing = false

    // CPU 低于此值视为"空闲"（单核占比）
    private let idleCPU = 5

    private var candidates: [ProcessSample] {
        OptimizationService.killableMemoryHogs(
            state.metrics.topMemProcesses, selfPID: Int(getpid()), limit: 12, minMB: 100)
    }
    private var selectedMemMB: Int {
        candidates.filter { selected.contains($0.pid) }.reduce(0) { $0 + $1.memMB }
    }
    private func fmt(_ mb: Int) -> String {
        mb >= 1024 ? String(format: "%.1f GB", Double(mb) / 1024) : "\(mb) MB"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("释放内存 · 选择要关闭的应用").font(.system(size: 14, weight: .semibold))
            Text("勾选空闲或占内存大的应用，关闭它们即可释放 RAM。\n⚠️ 会丢失未保存内容；系统进程已自动排除。")
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            if candidates.isEmpty {
                Text("没有可释放的第三方应用（≥100MB）。")
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(candidates, id: \.pid) { p in
                            let on = selected.contains(p.pid)
                            let idle = p.cpuPercent < idleCPU
                            HStack(spacing: 10) {
                                Image(systemName: on ? "checkmark.square.fill" : "square")
                                    .foregroundColor(on ? Theme.cool : .white.opacity(0.4))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(p.name).font(.system(size: 13)).lineLimit(1)
                                    Text("PID \(p.pid) · CPU \(p.cpuPercent)%")
                                        .font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
                                }
                                Spacer()
                                Text(idle ? "空闲" : "活跃")
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .overlay(Capsule().stroke((idle ? Theme.good : Theme.warm).opacity(0.5), lineWidth: 1))
                                    .foregroundColor(idle ? Theme.good : Theme.warm)
                                Text(fmt(p.memMB))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.85)).frame(width: 64, alignment: .trailing)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { if on { selected.remove(p.pid) } else { selected.insert(p.pid) } }
                            .padding(.vertical, 8)
                            Divider().background(Color.white.opacity(0.06))
                        }
                    }
                }
            }

            HStack {
                Text(selected.isEmpty ? "未选择" : "已选 \(selected.count) 项 · 约 \(fmt(selectedMemMB))")
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                Spacer()
                Button("取消") { onClose() }.buttonStyle(.bordered)
                Button(releasing ? "释放中…" : "释放选中") { release() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty || releasing)
            }
        }
        .padding(20)
        .frame(width: 380, height: 440)
    }

    private func release() {
        releasing = true
        let pids = Array(selected)
        DispatchQueue.global().async {
            let svc = OptimizationService()
            _ = svc.execute(.killProcesses, killPids: pids)
            DispatchQueue.main.async { releasing = false; onClose() }
        }
    }
}
