import Foundation
import Darwin

/// 内存压力等级——macOS 判断内存是否真正吃紧的官方信号。
/// 远比"Swap 用了多少"准确：Swap 高但压力 normal 时其实没问题。
public enum MemoryPressure: Int, Equatable, Sendable {
    case normal = 1
    case warning = 2
    case critical = 4

    /// 由内核返回的等级值映射（>=4 critical，>=2 warning，否则 normal）。纯函数。
    public static func from(level: Int) -> MemoryPressure {
        if level >= 4 { return .critical }
        if level >= 2 { return .warning }
        return .normal
    }

    public var label: String {
        switch self {
        case .normal: return "正常"
        case .warning: return "偏紧"
        case .critical: return "严重"
        }
    }
}

/// 薄层：读取 kern.memorystatus_vm_pressure_level。
public struct MemoryPressureProvider {
    public init() {}
    public func current() -> MemoryPressure {
        var level: Int32 = 1
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 {
            return MemoryPressure.from(level: Int(level))
        }
        return .normal
    }
}
