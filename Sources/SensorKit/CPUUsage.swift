import Foundation

/// CPU 累计时间片（跨全部核心求和）。
public struct CPUTicks: Equatable {
    public var user: Double
    public var system: Double
    public var idle: Double
    public var nice: Double
    public init(user: Double, system: Double, idle: Double, nice: Double) {
        self.user = user; self.system = system; self.idle = idle; self.nice = nice
    }
    public var busy: Double { user + system + nice }
    public var total: Double { busy + idle }
}

/// 纯函数：两次快照差值 → 占用百分比。
public enum CPUUsage {
    public static func percent(previous: CPUTicks, current: CPUTicks) -> Int {
        let totalDelta = current.total - previous.total
        let busyDelta = current.busy - previous.busy
        guard totalDelta > 0 else { return 0 }
        return Int((busyDelta / totalDelta * 100).rounded())
    }
}
