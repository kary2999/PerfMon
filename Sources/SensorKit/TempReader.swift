import Foundation
import IOKit

/// 薄层：通过 IOHIDEventSystemClient 枚举温度传感器，返回 (名字, 摄氏度) 列表。
/// 读不到时返回空数组——上层据此优雅降级显示“温度不可用”。
///
/// 性能：dlopen 句柄、函数符号、HID 客户端在初始化时解析一次并复用，
/// 避免每次采样都 dlopen + 创建客户端（这是之前 App 自身 CPU 偏高的主因之一）。
public final class TempReader {
    private let kTempUsagePage: Int32 = 0xff00
    private let kTempUsage: Int32 = 0x0005
    private let kIOHIDEventTypeTemperature: Int64 = 15
    private var kTempField: Int64 { 15 << 16 }

    private typealias CreateFn = @convention(c) (CFAllocator?) -> CFTypeRef?
    private typealias MatchFn  = @convention(c) (CFTypeRef?, CFDictionary?) -> Void
    private typealias CopyFn   = @convention(c) (CFTypeRef?) -> CFArray?
    private typealias EventFn  = @convention(c) (CFTypeRef?, Int64, Int32, Int64) -> CFTypeRef?
    private typealias FloatFn  = @convention(c) (CFTypeRef?, Int64) -> Double
    private typealias PropFn   = @convention(c) (CFTypeRef?, CFString) -> CFTypeRef?

    private var copyServices: CopyFn?
    private var copyEvent: EventFn?
    private var getFloat: FloatFn?
    private var copyProp: PropFn?
    private var client: CFTypeRef?
    private var ready = false

    public init() { setup() }

    private func setup() {
        guard let handle = dlopen(nil, RTLD_NOW) else { return }
        guard
            let pCreate = dlsym(handle, "IOHIDEventSystemClientCreate"),
            let pMatch  = dlsym(handle, "IOHIDEventSystemClientSetMatching"),
            let pCopy   = dlsym(handle, "IOHIDEventSystemClientCopyServices"),
            let pEvent  = dlsym(handle, "IOHIDServiceClientCopyEvent"),
            let pFloat  = dlsym(handle, "IOHIDEventGetFloatValue"),
            let pProp   = dlsym(handle, "IOHIDServiceClientCopyProperty")
        else { return }

        let create = unsafeBitCast(pCreate, to: CreateFn.self)
        let setMatching = unsafeBitCast(pMatch, to: MatchFn.self)
        copyServices = unsafeBitCast(pCopy, to: CopyFn.self)
        copyEvent = unsafeBitCast(pEvent, to: EventFn.self)
        getFloat = unsafeBitCast(pFloat, to: FloatFn.self)
        copyProp = unsafeBitCast(pProp, to: PropFn.self)

        guard let c = create(kCFAllocatorDefault) else { return }
        setMatching(c, ["PrimaryUsagePage": kTempUsagePage,
                        "PrimaryUsage": kTempUsage] as CFDictionary)
        client = c
        ready = true
    }

    public func readAll() -> [(String, Double)] {
        guard ready,
              let copyServices, let copyEvent, let getFloat, let copyProp,
              let services = copyServices(client) as? [CFTypeRef]
        else { return [] }

        var out: [(String, Double)] = []
        for svc in services {
            guard let event = copyEvent(svc, kIOHIDEventTypeTemperature, 0, 0) else { continue }
            let temp = getFloat(event, kTempField)
            let name = (copyProp(svc, "Product" as CFString) as? String) ?? "Sensor"
            if temp > 0 && temp < 130 {
                out.append((name, (temp * 10).rounded() / 10))
            }
        }
        return out
    }
}
