import Foundation
import Darwin

public struct MemoryInfo: Equatable {
    public var usedBytes: UInt64
    public var totalBytes: UInt64
    public var appBytes: UInt64        // 活跃应用占用（active）
    public var wiredBytes: UInt64      // 系统驻留（wired）
    public var compressedBytes: UInt64 // 压缩内存
    public var freeBytes: UInt64       // 空闲 + 不活跃（可回收）

    public init(usedBytes: UInt64, totalBytes: UInt64,
                appBytes: UInt64 = 0, wiredBytes: UInt64 = 0,
                compressedBytes: UInt64 = 0, freeBytes: UInt64 = 0) {
        self.usedBytes = usedBytes; self.totalBytes = totalBytes
        self.appBytes = appBytes; self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes; self.freeBytes = freeBytes
    }
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
        // 与「活动监视器」一致的口径：
        //   App 内存 = internal_page_count − purgeable_count（匿名内存，不含文件缓存）
        //   已用     = App 内存 + 系统驻留(wired) + 压缩(compressed)
        //   可用     = free + 文件缓存(external) + 可清除(purgeable)
        let internalPages = UInt64(stats.internal_page_count)
        let purgeable = UInt64(stats.purgeable_count)
        let app = (internalPages > purgeable ? internalPages - purgeable : 0) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let free = (UInt64(stats.free_count) + UInt64(stats.external_page_count) + purgeable) * pageSize
        let used = app + wired + compressed
        return MemoryInfo(usedBytes: used, totalBytes: total,
                          appBytes: app, wiredBytes: wired,
                          compressedBytes: compressed, freeBytes: free)
    }
}
