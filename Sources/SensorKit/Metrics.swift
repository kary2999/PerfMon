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

    public init(cpuPercent: Int, memPercent: Int, swapPercent: Int,
                load1: Double, uptimeDays: Int, temps: Temperatures,
                topProcesses: [ProcessSample]) {
        self.cpuPercent = cpuPercent; self.memPercent = memPercent
        self.swapPercent = swapPercent; self.load1 = load1
        self.uptimeDays = uptimeDays; self.temps = temps
        self.topProcesses = topProcesses
    }

    public static let empty = Metrics(cpuPercent: 0, memPercent: 0, swapPercent: 0,
                                      load1: 0, uptimeDays: 0,
                                      temps: Temperatures(cpu: nil, gpu: nil),
                                      topProcesses: [])

    /// 纯函数：综合健康分 0–100（越高越健康）。
    /// 三项加权扣分：CPU 30%、内存 30%、Swap 40%（Swap 打满对体验影响最大）。
    public static func healthScore(_ m: Metrics) -> Int {
        let penalty = Double(m.cpuPercent) * 0.30
                    + Double(m.memPercent) * 0.30
                    + Double(m.swapPercent) * 0.40
        return max(0, min(100, 100 - Int(penalty.rounded())))
    }
}
