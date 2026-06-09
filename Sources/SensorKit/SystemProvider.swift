import Foundation
import Darwin

public enum Uptime {
    /// 由 boot/now 的 epoch 秒算运行天数（向下取整）。纯函数。
    public static func days(bootEpoch: Int, nowEpoch: Int) -> Int {
        max(0, (nowEpoch - bootEpoch) / 86_400)
    }
}

public struct SystemInfo: Equatable {
    public var load1: Double
    public var uptimeDays: Int
}

/// 薄层：getloadavg + sysctl kern.boottime。
public struct SystemProvider {
    public init() {}

    public func current() -> SystemInfo {
        var loads = [Double](repeating: 0, count: 3)
        getloadavg(&loads, 3)

        var bt = timeval()
        var size = MemoryLayout<timeval>.size
        var bootEpoch = 0
        if sysctlbyname("kern.boottime", &bt, &size, nil, 0) == 0 {
            bootEpoch = bt.tv_sec
        }
        let now = Int(Date().timeIntervalSince1970)
        return SystemInfo(load1: (loads[0] * 100).rounded() / 100,
                          uptimeDays: Uptime.days(bootEpoch: bootEpoch, nowEpoch: now))
    }
}
