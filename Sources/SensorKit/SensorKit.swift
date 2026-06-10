import Foundation

/// 门面：聚合各 Provider，产出一份 Metrics 快照。
/// CPU 需要两次 tick，故内部保存上一次。
/// 性能：温度/进程属于"慢采样"（开销大），可通过 refreshSlow=false 跳过、复用上次缓存，
/// 让上层以更低频率刷新这两项，显著降低 App 自身 CPU 占用。
public final class SensorKit {
    private let cpuProvider = CPUProvider()
    private let memProvider = MemoryProvider()
    private let swapProvider = SwapProvider()
    private let sysProvider = SystemProvider()
    private let pressureProvider = MemoryPressureProvider()
    private let tempReader = TempReader()
    private let procProvider = ProcessProvider()
    private var lastTicks: CPUTicks?

    // 慢采样缓存
    private var cachedTemps = Temperatures(cpu: nil, gpu: nil)
    private var cachedProcs: [ProcessSample] = []

    public init() {
        lastTicks = cpuProvider.currentTicks()   // 预热一帧
    }

    public func snapshot(refreshSlow: Bool = true) -> Metrics {
        var cpu = 0
        if let cur = cpuProvider.currentTicks() {
            if let prev = lastTicks { cpu = CPUUsage.percent(previous: prev, current: cur) }
            lastTicks = cur
        }
        var memPct = 0
        var memUsedGB = 0.0, memTotalGB = 0.0, memAppGB = 0.0, memWiredGB = 0.0, memCompGB = 0.0
        if let mem = memProvider.current() {
            memPct = Percent.ratio(used: Double(mem.usedBytes), total: Double(mem.totalBytes))
            let gb = { (b: UInt64) in (Double(b) / 1_073_741_824.0 * 10).rounded() / 10 }
            memUsedGB = gb(mem.usedBytes); memTotalGB = gb(mem.totalBytes)
            memAppGB = gb(mem.appBytes); memWiredGB = gb(mem.wiredBytes); memCompGB = gb(mem.compressedBytes)
        }
        var swapPct = 0
        if let sw = swapProvider.current() {
            swapPct = Percent.ratio(used: Double(sw.usedBytes), total: Double(sw.totalBytes))
        }
        let sys = sysProvider.current()

        // 慢采样：温度 + 进程，仅在需要时刷新，否则复用缓存。
        if refreshSlow {
            cachedTemps = TempClassifier.classify(tempReader.readAll())
            cachedProcs = procProvider.top(limit: 8)
        }

        return Metrics(cpuPercent: cpu, memPercent: memPct, swapPercent: swapPct,
                       load1: sys.load1, uptimeDays: sys.uptimeDays,
                       temps: cachedTemps, topProcesses: cachedProcs,
                       pressure: pressureProvider.current(),
                       memUsedGB: memUsedGB, memTotalGB: memTotalGB,
                       memAppGB: memAppGB, memWiredGB: memWiredGB, memCompressedGB: memCompGB)
    }
}
