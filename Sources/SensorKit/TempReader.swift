import Foundation
import IOKit

/// 薄层：通过 IOHIDEventSystemClient 枚举温度传感器，返回 (名字, 摄氏度) 列表。
/// 读不到时返回空数组——上层据此优雅降级显示“温度不可用”。
public struct TempReader {
    // kHIDPage_AppleVendor=0xff00；temperature usage=5；temperature event type=15。
    private let kTempUsagePage: Int32 = 0xff00
    private let kTempUsage: Int32 = 0x0005
    private let kIOHIDEventTypeTemperature: Int64 = 15
    private var kTempField: Int64 { 15 << 16 }   // field = (type << 16)

    public init() {}

    public func readAll() -> [(String, Double)] {
        guard let handle = dlopen(nil, RTLD_NOW) else { return [] }
        defer { dlclose(handle) }
        guard
            let pCreate = dlsym(handle, "IOHIDEventSystemClientCreate"),
            let pMatch  = dlsym(handle, "IOHIDEventSystemClientSetMatching"),
            let pCopy   = dlsym(handle, "IOHIDEventSystemClientCopyServices"),
            let pEvent  = dlsym(handle, "IOHIDServiceClientCopyEvent"),
            let pFloat  = dlsym(handle, "IOHIDEventGetFloatValue"),
            let pProp   = dlsym(handle, "IOHIDServiceClientCopyProperty")
        else { return [] }

        typealias CreateFn = @convention(c) (CFAllocator?) -> CFTypeRef?
        typealias MatchFn  = @convention(c) (CFTypeRef?, CFDictionary?) -> Void
        typealias CopyFn   = @convention(c) (CFTypeRef?) -> CFArray?
        typealias EventFn  = @convention(c) (CFTypeRef?, Int64, Int32, Int64) -> CFTypeRef?
        typealias FloatFn  = @convention(c) (CFTypeRef?, Int64) -> Double
        typealias PropFn   = @convention(c) (CFTypeRef?, CFString) -> CFTypeRef?

        let create = unsafeBitCast(pCreate, to: CreateFn.self)
        let setMatching = unsafeBitCast(pMatch, to: MatchFn.self)
        let copyServices = unsafeBitCast(pCopy, to: CopyFn.self)
        let copyEvent = unsafeBitCast(pEvent, to: EventFn.self)
        let getFloat = unsafeBitCast(pFloat, to: FloatFn.self)
        let copyProp = unsafeBitCast(pProp, to: PropFn.self)

        guard let client = create(kCFAllocatorDefault) else { return [] }
        let matching: [String: Any] = [
            "PrimaryUsagePage": kTempUsagePage,
            "PrimaryUsage": kTempUsage,
        ]
        setMatching(client, matching as CFDictionary)
        guard let services = copyServices(client) as? [CFTypeRef] else { return [] }

        var out: [(String, Double)] = []
        for svc in services {
            guard let event = copyEvent(svc, kIOHIDEventTypeTemperature, 0, 0) else { continue }
            let temp = getFloat(event, kTempField)
            let name = (copyProp(svc, "Product" as CFString) as? String) ?? "Sensor"
            if temp > 0 && temp < 130 {   // 合理范围过滤
                out.append((name, (temp * 10).rounded() / 10))
            }
        }
        return out
    }
}
