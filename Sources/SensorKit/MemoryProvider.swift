import Foundation
import Darwin

public struct MemoryInfo: Equatable {
    public var usedBytes: UInt64
    public var totalBytes: UInt64
}

/// 薄层：host_statistics64 取页统计 + hw.memsize 取总内存。
public struct MemoryProvider {
    public init() {}

    public func current() -> MemoryInfo? {
        // 总内存
        var total: UInt64 = 0
        var sizeTotal = MemoryLayout<UInt64>.size
        guard sysctlbyname("hw.memsize", &total, &sizeTotal, nil, 0) == 0 else { return nil }

        // 页统计
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(vm_kernel_page_size)
        // “已用”= active + wired + compressed（inactive/free 视为可回收）
        let used = (UInt64(stats.active_count)
                    + UInt64(stats.wire_count)
                    + UInt64(stats.compressor_page_count)) * pageSize
        return MemoryInfo(usedBytes: used, totalBytes: total)
    }
}
