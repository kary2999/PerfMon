import Foundation
import Darwin

/// 薄层：通过 host_processor_info 读取全核累计 CPU tick。
public struct CPUProvider {
    public init() {}

    public func currentTicks() -> CPUTicks? {
        var count = mach_msg_type_number_t(0)
        var cpuLoad: processor_info_array_t?
        var cpuCount: natural_t = 0
        let result = host_processor_info(mach_host_self(),
                                         PROCESSOR_CPU_LOAD_INFO,
                                         &cpuCount,
                                         &cpuLoad,
                                         &count)
        guard result == KERN_SUCCESS, let cpuLoad else { return nil }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(UInt(bitPattern: cpuLoad)),
                          vm_size_t(Int(count) * MemoryLayout<integer_t>.size))
        }
        var ticks = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let states = Int(CPU_STATE_MAX)
        for i in 0..<Int(cpuCount) {
            let base = i * states
            ticks.user   += Double(cpuLoad[base + Int(CPU_STATE_USER)])
            ticks.system += Double(cpuLoad[base + Int(CPU_STATE_SYSTEM)])
            ticks.idle   += Double(cpuLoad[base + Int(CPU_STATE_IDLE)])
            ticks.nice   += Double(cpuLoad[base + Int(CPU_STATE_NICE)])
        }
        return ticks
    }
}
