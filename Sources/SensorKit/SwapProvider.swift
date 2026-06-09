import Foundation
import Darwin

public enum SwapStats {
    /// 字节 → GB（保留 1 位小数）。纯函数，便于测试。
    public static func toGB(bytes: UInt64) -> Double {
        (Double(bytes) / 1_073_741_824.0 * 10).rounded() / 10
    }
}

public struct SwapInfo: Equatable {
    public var usedBytes: UInt64
    public var totalBytes: UInt64
}

/// 薄层：sysctl vm.swapusage。
public struct SwapProvider {
    public init() {}
    public func current() -> SwapInfo? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let r = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        guard r == 0 else { return nil }
        return SwapInfo(usedBytes: usage.xsu_used, totalBytes: usage.xsu_total)
    }
}
