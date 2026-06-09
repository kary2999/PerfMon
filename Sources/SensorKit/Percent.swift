import Foundation

/// 纯函数：占比计算，集中处理除零与取整。
public enum Percent {
    /// used/total 的百分比，四舍五入到整数；total<=0 返回 0。
    public static func ratio(used: Double, total: Double) -> Int {
        guard total > 0 else { return 0 }
        return Int((used / total * 100).rounded())
    }
}
