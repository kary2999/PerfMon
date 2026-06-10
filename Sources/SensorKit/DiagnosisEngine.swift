import Foundation

public enum IssueSeverity: String, Equatable, Sendable {
    case critical, warning, info
}

public struct Issue: Equatable, Sendable, Identifiable {
    public var id: String { code }
    public var code: String           // 规则标识，稳定唯一
    public var severity: IssueSeverity
    public var title: String
    public var detail: String
    public var suggestedAction: String?   // 关联一键加速动作 key，nil = 仅提示
    public init(code: String, severity: IssueSeverity, title: String,
                detail: String, suggestedAction: String?) {
        self.code = code; self.severity = severity; self.title = title
        self.detail = detail; self.suggestedAction = suggestedAction
    }
}

/// 纯函数引擎：输入指标快照，输出问题清单（按严重度排序）。
public enum DiagnosisEngine {
    // 阈值集中管理，便于调整与测试。
    static let swapHigh = 80
    static let cpuWarning = 85
    static let procCritical = 40
    static let uptimeWarningDays = 7
    static let memHogMB = 800        // 单个应用内存超过此值视为"大型应用"

    static func fmtMem(_ mb: Int) -> String {
        mb >= 1024 ? String(format: "%.1f GB", Double(mb) / 1024) : "\(mb) MB"
    }

    public static func analyze(_ m: Metrics) -> [Issue] {
        var issues: [Issue] = []

        // 以「内存压力」为准，而非 Swap 用量。
        switch m.pressure {
        case .critical:
            issues.append(Issue(
                code: "mem_pressure", severity: .critical,
                title: "内存压力严重",
                detail: "系统内存真正吃紧、正在频繁换页，这会导致卡顿发热。建议释放内存或关闭高占用 App。",
                suggestedAction: "purge"))
        case .warning:
            issues.append(Issue(
                code: "mem_pressure", severity: .warning,
                title: "内存压力偏紧",
                detail: "可用内存开始紧张。建议释放内存或留意大内存 App。",
                suggestedAction: "purge"))
        case .normal:
            // 压力正常但 Swap 高：这是 macOS 正常机制，给一条"安心"提示，不算问题。
            if m.swapPercent >= swapHigh {
                issues.append(Issue(
                    code: "swap_ok", severity: .info,
                    title: "Swap 用量较高（\(m.swapPercent)%），但内存压力正常",
                    detail: "这是 macOS 的正常机制：换出的数据停在磁盘上不影响使用，无需清理（只有重启才会清空）。",
                    suggestedAction: nil))
            }
        }

        // 单进程高占用
        if let top = m.topProcesses.first(where: { $0.cpuPercent >= procCritical }) {
            issues.append(Issue(
                code: "proc_high_\(top.pid)", severity: .warning,
                title: "\(top.name) 占用 CPU \(top.cpuPercent)%",
                detail: "该进程占用过高，是当前主要热源。可重启该应用或结束进程。",
                suggestedAction: "kill"))
        }

        if m.cpuPercent >= cpuWarning {
            issues.append(Issue(
                code: "cpu_high", severity: .warning,
                title: "CPU 总占用偏高（\(m.cpuPercent)%）",
                detail: "整体负载高，可能持续发热。检查进程页找出占用来源。",
                suggestedAction: nil))
        }

        // 大型应用内存偏高（常见于 Electron / 浏览器类）：提示可重启释放。
        if let hog = m.topMemProcesses.first(where: { $0.memMB >= memHogMB }) {
            let normal = (m.pressure == .normal)
            issues.append(Issue(
                code: "mem_hog_\(hog.pid)",
                severity: normal ? .info : .warning,
                title: "\(hog.name) 占用内存 \(fmtMem(hog.memMB))",
                detail: "大型应用（常见于 Electron / 浏览器 / AI 助手类）。"
                    + (normal
                       ? "当前内存压力正常，无需处理；日后变卡时可重启该应用释放。"
                       : "内存偏紧，建议重启该应用以释放内存。"),
                suggestedAction: nil))
        }

        if m.uptimeDays >= uptimeWarningDays {
            issues.append(Issue(
                code: "uptime_high", severity: .info,
                title: "系统已连续运行 \(m.uptimeDays) 天未重启",
                detail: "长期不重启会累积内存碎片与图形异常。建议重启释放资源。",
                suggestedAction: nil))
        }

        // 按严重度排序：critical > warning > info
        let order: [IssueSeverity: Int] = [.critical: 0, .warning: 1, .info: 2]
        return issues.sorted { (order[$0.severity] ?? 9) < (order[$1.severity] ?? 9) }
    }
}
