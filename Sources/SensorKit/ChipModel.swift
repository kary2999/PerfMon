import Foundation

public enum ChipModel: Equatable {
    case m1, m2, m3, m4, m5, unknown

    /// 从 machdep.cpu.brand_string 解析代次。只认 M1–M5；其余 unknown。
    public static func parse(_ brand: String) -> ChipModel {
        let s = brand.lowercased()
        guard s.contains("apple m") else { return .unknown }
        if s.contains("m1") { return .m1 }
        if s.contains("m2") { return .m2 }
        if s.contains("m3") { return .m3 }
        if s.contains("m4") { return .m4 }
        if s.contains("m5") { return .m5 }
        return .unknown
    }

    /// 读取本机 brand string（薄层）。
    public static func current() -> ChipModel {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return .unknown }
        var buf = [UInt8](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0)
        if let nul = buf.firstIndex(of: 0) { buf.removeSubrange(nul...) }
        return parse(String(decoding: buf, as: UTF8.self))
    }
}
