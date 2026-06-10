import Foundation

/// 自动清理策略（纯函数，便于测试）。
/// 规则：开启 + 已用内存超过阈值 + 距上次清理 ≥ 最小间隔（写死 1 小时，防止频繁刷）。
public enum AutoCleanPolicy {
    /// 最小自动清理间隔——硬编码 1 小时，不可配置（防止 App 高频自刷）。
    public static let minIntervalSeconds: TimeInterval = 3600

    public static func shouldClean(memUsedGB: Double,
                                   thresholdGB: Double,
                                   secondsSinceLastClean: TimeInterval,
                                   enabled: Bool) -> Bool {
        guard enabled else { return false }
        guard memUsedGB > thresholdGB else { return false }
        return secondsSinceLastClean >= minIntervalSeconds
    }
}
