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
    @Published var swapHistory: [Double] = []        // Swap 已用 GB，按慢采样记录
    /// 慢采样间隔（秒）= 快间隔 × N，用于 Swap 增长速率计算。
    var slowIntervalSec: Double { fastInterval * Double(slowEveryNTicks) }

    // 自动清理配置（持久化）。阈值可调；间隔写死 1 小时（见 AutoCleanPolicy）。
    @Published var autoCleanEnabled: Bool {
        didSet { UserDefaults.standard.set(autoCleanEnabled, forKey: "autoCleanEnabled") }
    }
    @Published var autoCleanThresholdGB: Double {
        didSet { UserDefaults.standard.set(autoCleanThresholdGB, forKey: "autoCleanThresholdGB") }
    }
    private var lastAutoClean: Date?

    private let highCPUThreshold = 50

    private let kit = SensorKit()
    let boost = OptimizationService()
    private var timer: Timer?
    private var tickCount = 0

    init() {
        let d = UserDefaults.standard
        autoCleanEnabled = d.object(forKey: "autoCleanEnabled") as? Bool ?? false
        autoCleanThresholdGB = d.object(forKey: "autoCleanThresholdGB") as? Double ?? 5.0
    }

    // 采样节流：CPU/内存等轻量项每 2 秒；温度/进程等重量项每 3 个 tick（=6 秒）刷新一次。
    private let fastInterval: TimeInterval = 2.0
    private let slowEveryNTicks = 3

    /// 结束指定进程（用于进程页）。
    func killProcess(pid: Int) {
        _ = boost.execute(.killProcesses, killPids: [pid])
    }

    /// 快速加速：仅执行「免密」动作（清缓存 + 降图形负载），不触发管理员授权弹窗。
    /// 需要密码的 purge 留在「优化」页作为可选项。
    func quickBoost() {
        DispatchQueue.global().async { [boost] in
            _ = boost.execute(.clearCaches)
            _ = boost.execute(.reduceEffects)
        }
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
            // Swap 增长趋势采样
            swapHistory.append(m.swapUsedGB)
            if swapHistory.count > 60 { swapHistory.removeFirst() }
        }
        maybeAutoClean(m)
    }

    /// 自动清理：内存超阈值且距上次 ≥1 小时时，自动清缓存（非破坏性、不弹密码）。
    private func maybeAutoClean(_ m: Metrics) {
        let since = lastAutoClean.map { Date().timeIntervalSince($0) } ?? .greatestFiniteMagnitude
        guard AutoCleanPolicy.shouldClean(memUsedGB: m.memUsedGB,
                                          thresholdGB: autoCleanThresholdGB,
                                          secondsSinceLastClean: since,
                                          enabled: autoCleanEnabled) else { return }
        lastAutoClean = Date()
        DispatchQueue.global().async {
            let svc = OptimizationService()
            _ = svc.execute(.clearCaches)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .autoCleanDone, object: nil)
            }
        }
    }
}
