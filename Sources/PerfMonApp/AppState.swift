import Foundation
import SwiftUI
import Combine
import SensorKit

/// 一条高占用记录：某时刻某进程 CPU 超过阈值。
struct HighCPUEntry: Identifiable {
    let id = UUID()
    let time: Date
    let name: String
    let cpu: Int          // 单核占比（ps 口径，可 >100）
}

final class AppState: ObservableObject {
    @Published var metrics: Metrics = .empty
    @Published var cpuHistory: [Double] = []
    @Published var cpuTempHistory: [Double] = []
    @Published var highCPULog: [HighCPUEntry] = []   // CPU 超过 50% 的进程记录

    private let highCPUThreshold = 50

    private let kit = SensorKit()
    let boost = OptimizationService()
    private var timer: Timer?
    private var tickCount = 0

    // 采样节流：CPU/内存等轻量项每 2 秒；温度/进程等重量项每 3 个 tick（=6 秒）刷新一次。
    private let fastInterval: TimeInterval = 2.0
    private let slowEveryNTicks = 3

    /// 结束指定进程（用于进程页）。
    func killProcess(pid: Int) {
        _ = boost.execute(.killProcesses, killPids: [pid])
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: fastInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    private func tick() {
        let refreshSlow = (tickCount % slowEveryNTicks == 0)
        tickCount &+= 1
        let m = kit.snapshot(refreshSlow: refreshSlow)
        metrics = m
        cpuHistory.append(Double(m.cpuPercent))
        if cpuHistory.count > 60 { cpuHistory.removeFirst() }
        if let t = m.temps.cpu {
            cpuTempHistory.append(t)
            if cpuTempHistory.count > 60 { cpuTempHistory.removeFirst() }
        }
        // 记录 CPU 超过阈值的进程（仅在慢采样刷新了进程时记，避免重复）。
        if refreshSlow {
            let now = Date()
            for p in m.topProcesses where p.cpuPercent >= highCPUThreshold && p.name != "PerfMon" {
                highCPULog.insert(HighCPUEntry(time: now, name: p.name, cpu: p.cpuPercent), at: 0)
            }
            if highCPULog.count > 50 { highCPULog.removeLast(highCPULog.count - 50) }
        }
    }
}
