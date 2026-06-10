import Foundation

/// Swap 趋势分析（纯函数）。
/// 说明：macOS 不公开"每进程 swap 用量"，故只能分析总量随时间的增长速率，
/// 并由内存占用推断可能的贡献者（见上层 UI 标注）。
public enum SwapTrend {
    /// 每分钟增长 GB。samples 按时间先后排列，sampleIntervalSec 为相邻采样间隔。
    public static func growthPerMinute(_ samples: [Double], sampleIntervalSec: Double) -> Double {
        guard samples.count >= 2, sampleIntervalSec > 0 else { return 0 }
        let span = Double(samples.count - 1) * sampleIntervalSec
        let delta = samples[samples.count - 1] - samples[0]
        return (delta / span * 60 * 100).rounded() / 100
    }

    public enum Direction: String, Sendable { case rising = "上升", falling = "下降", stable = "稳定" }

    public static func direction(growthPerMin: Double) -> Direction {
        if growthPerMin >= 0.1 { return .rising }
        if growthPerMin <= -0.1 { return .falling }
        return .stable
    }
}
