import Foundation

public struct ProcessSample: Equatable, Sendable {
    public var pid: Int
    public var name: String
    public var cpuPercent: Int
    public init(pid: Int, name: String, cpuPercent: Int) {
        self.pid = pid; self.name = name; self.cpuPercent = cpuPercent
    }
}

public struct Metrics: Equatable, Sendable {
    public var cpuPercent: Int
    public var memPercent: Int
    public var swapPercent: Int
    public var load1: Double
    public var uptimeDays: Int
    public var temps: Temperatures
    public var topProcesses: [ProcessSample]
    public var pressure: MemoryPressure
    // 内存明细（GB），用于详情展示
    public var memUsedGB: Double
    public var memTotalGB: Double
    public var memAppGB: Double
    public var memWiredGB: Double
    public var memCompressedGB: Double

    public init(cpuPercent: Int, memPercent: Int, swapPercent: Int,
                load1: Double, uptimeDays: Int, temps: Temperatures,
                topProcesses: [ProcessSample],
                pressure: MemoryPressure = .normal,
                memUsedGB: Double = 0, memTotalGB: Double = 0,
                memAppGB: Double = 0, memWiredGB: Double = 0, memCompressedGB: Double = 0) {
        self.cpuPercent = cpuPercent; self.memPercent = memPercent
        self.swapPercent = swapPercent; self.load1 = load1
        self.uptimeDays = uptimeDays; self.temps = temps
        self.topProcesses = topProcesses; self.pressure = pressure
        self.memUsedGB = memUsedGB; self.memTotalGB = memTotalGB
        self.memAppGB = memAppGB; self.memWiredGB = memWiredGB
        self.memCompressedGB = memCompressedGB
    }

    public static let empty = Metrics(cpuPercent: 0, memPercent: 0, swapPercent: 0,
                                      load1: 0, uptimeDays: 0,
                                      temps: Temperatures(cpu: nil, gpu: nil),
                                      topProcesses: [], pressure: .normal)

    /// 纯函数：综合健康分 0–100（越高越健康）。
    /// 以「内存压力」为主导（macOS 真实信号），CPU 次之；
    /// Swap 不参与扣分——Swap 高但压力正常时并非问题。
    public static func healthScore(_ m: Metrics) -> Int {
        var penalty = Double(m.cpuPercent) * 0.35
        switch m.pressure {
        case .normal: break
        case .warning: penalty += 25
        case .critical: penalty += 55
        }
        return max(0, min(100, 100 - Int(penalty.rounded())))
    }
}
