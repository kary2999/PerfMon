import SwiftUI
import SensorKit

struct ProcessView: View {
    @ObservedObject var state: AppState
    @State private var confirmKill: ProcessSample?
    @State private var sortByMem = false

    private var list: [ProcessSample] {
        sortByMem ? state.metrics.topMemProcesses : state.metrics.topProcesses
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("进程占用排行").font(.system(size: 14, weight: .semibold))
                Spacer()
                Picker("", selection: $sortByMem) {
                    Text("CPU").tag(false)
                    Text("内存").tag(true)
                }
                .pickerStyle(.segmented).frame(width: 130).labelsHidden()
            }
            Text(sortByMem
                 ? "按内存 (RSS) 排序 · 点击 × 结束进程（会丢失未保存内容）"
                 : "按 CPU 排序（单核占比，多核可超 100%）· 点击 × 结束进程")
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(list, id: \.pid) { p in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(sortByMem ? Theme.warm : Theme.byLoad(p.cpuPercent))
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(p.name).font(.system(size: 13))
                                Text("PID \(p.pid)").font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
                            }
                            Spacer()
                            // 两个口径都展示，但高亮当前排序项
                            Text(fmtMem(p.memMB))
                                .font(.system(size: 12, weight: sortByMem ? .bold : .regular, design: .monospaced))
                                .foregroundColor(sortByMem ? Theme.warm : .white.opacity(0.45))
                            Text("\(p.cpuPercent)%")
                                .font(.system(size: 12, weight: sortByMem ? .regular : .bold, design: .monospaced))
                                .foregroundColor(sortByMem ? .white.opacity(0.45) : Theme.byLoad(p.cpuPercent))
                                .frame(width: 44, alignment: .trailing)
                            Button { confirmKill = p } label: {
                                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                    .frame(width: 18, height: 18)
                                    .background(Color.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 5))
                            }.buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        Divider().background(Color.white.opacity(0.06))
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 480, height: 400)
        .alert("结束进程？", isPresented: Binding(
            get: { confirmKill != nil },
            set: { if !$0 { confirmKill = nil } })) {
            Button("取消", role: .cancel) { confirmKill = nil }
            Button("结束", role: .destructive) {
                if let p = confirmKill { state.killProcess(pid: p.pid) }
                confirmKill = nil
            }
        } message: {
            Text("将结束 \(confirmKill?.name ?? "")（PID \(confirmKill?.pid ?? 0)）。未保存内容会丢失。")
        }
    }

    private func fmtMem(_ mb: Int) -> String {
        mb >= 1024 ? String(format: "%.1fG", Double(mb) / 1024) : "\(mb)M"
    }
}
