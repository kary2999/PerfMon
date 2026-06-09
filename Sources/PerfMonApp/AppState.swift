import Foundation
import SwiftUI
import Combine
import SensorKit

final class AppState: ObservableObject {
    @Published var metrics: Metrics = .empty
    @Published var cpuHistory: [Double] = []
    @Published var cpuTempHistory: [Double] = []

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
    }
}
