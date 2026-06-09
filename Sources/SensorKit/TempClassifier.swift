import Foundation

public struct Temperatures: Equatable, Sendable {
    public var cpu: Double?   // nil = 不可用（绝不编造）
    public var gpu: Double?
    public init(cpu: Double?, gpu: Double?) { self.cpu = cpu; self.gpu = gpu }
}

/// 纯函数：按传感器名关键词把读数归类为 CPU / GPU，并取每类最大值。
/// 跨芯片兼容的兜底层：即便各代命名不同，只要含关键词即可命中。
public enum TempClassifier {
    // CPU/SoC：含明确核心名（pACC/eACC/CPU/SOC），以及 Apple Silicon 实际暴露的
    // die 温度（tdie/tcal）。排除设备温度 tdev、NAND、电池等非芯片传感器。
    static let cpuKeywords = ["pacc", "eacc", "cpu", "soc", "tdie", "tcal"]
    static let gpuKeywords = ["gpu"]

    public static func classify(_ sensors: [(String, Double)]) -> Temperatures {
        var cpu: Double? = nil
        var gpu: Double? = nil
        for (name, value) in sensors {
            let n = name.lowercased()
            if gpuKeywords.contains(where: n.contains) {
                gpu = max(gpu ?? -.infinity, value)
            } else if cpuKeywords.contains(where: n.contains) {
                cpu = max(cpu ?? -.infinity, value)
            }
        }
        return Temperatures(cpu: cpu, gpu: gpu)
    }
}
