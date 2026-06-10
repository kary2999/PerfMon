import Foundation

/// 语义化版本比较（纯函数）。支持 "1.2.3" 或 "v1.2.3"。
public enum SemVer {
    public static func parts(_ s: String) -> [Int] {
        s.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            .split(separator: ".")
            .map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
    }

    /// candidate 是否比 current 新。
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = parts(candidate), b = parts(current)
        let n = max(a.count, b.count)
        for i in 0..<n {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
