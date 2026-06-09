import Foundation

/// 门面：聚合各 Provider，产出一份 Metrics 快照。
/// CPU 需要两次 tick，故内部保存上一次。
public final class SensorKit {
    private let cpuProvider = CPUProvider()
    private let memProvider = MemoryProvider()
    private let swapProvider = SwapProvider()
    private let sysProvider = SystemProvider()
    private let tempReader = TempReader()
    private var lastTicks: CPUTicks?

    public init() {
        lastTicks = cpuProvider.currentTicks()   // 预热一帧
    }

    public func snapshot() -> Metrics {
        var cpu = 0
        if let cur = cpuProvider.currentTicks() {
            if let prev = lastTicks { cpu = CPUUsage.percent(previous: prev, current: cur) }
            lastTicks = cur
        }
        var memPct = 0
        if let mem = memProvider.current() {
            memPct = Percent.ratio(used: Double(mem.usedBytes), total: Double(mem.totalBytes))
        }
        var swapPct = 0
        if let sw = swapProvider.current() {
            swapPct = Percent.ratio(used: Double(sw.usedBytes), total: Double(sw.totalBytes))
        }
        let sys = sysProvider.current()
        let temps = TempClassifier.classify(tempReader.readAll())

        return Metrics(cpuPercent: cpu, memPercent: memPct, swapPercent: swapPct,
                       load1: sys.load1, uptimeDays: sys.uptimeDays,
                       temps: temps, topProcesses: [])
    }
}
