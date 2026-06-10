import Foundation

public enum BoostAction: String, Equatable, Sendable, CaseIterable {
    case purgeMemory      // sudo purge
    case killProcesses    // kill 选中进程
    case clearCaches      // 清 ~/Library/Caches
    case reduceEffects    // 降低图形特效

    public var title: String {
        switch self {
        case .purgeMemory: return "释放不活跃内存"
        case .killProcesses: return "结束高占用进程"
        case .clearCaches: return "清理用户缓存"
        case .reduceEffects: return "降低图形合成负载"
        }
    }
    public var command: String {
        switch self {
        case .purgeMemory: return "sudo purge"
        case .killProcesses: return "kill <pid>"
        case .clearCaches: return "rm -rf ~/Library/Caches/*"
        case .reduceEffects: return "defaults write … reduceTransparency"
        }
    }
    public var isRisky: Bool { self == .killProcesses || self == .purgeMemory }
    public var isReversible: Bool { self == .reduceEffects || self == .clearCaches }
}

public struct BoostStepResult: Equatable, Sendable {
    public var action: BoostAction
    public var ok: Bool
    public var message: String       // 日志文案
    public init(action: BoostAction, ok: Bool, message: String) {
        self.action = action; self.ok = ok; self.message = message
    }
}

/// 命令执行抽象，便于测试时注入 mock（不真的 kill/purge）。
public protocol CommandRunner: Sendable {
    /// 执行命令，返回 (是否成功, 输出)。
    func run(_ launchPath: String, _ args: [String]) -> (Bool, String)
}

/// 真实执行器：用 Process 跑命令。
public struct ShellRunner: CommandRunner {
    public init() {}
    public func run(_ launchPath: String, _ args: [String]) -> (Bool, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return (p.terminationStatus == 0, String(decoding: data, as: UTF8.self))
        } catch {
            return (false, "\(error)")
        }
    }
}

/// 一键加速编排。动作的"决定哪些可做"是纯函数；执行通过注入的 runner。
public final class OptimizationService {
    private let runner: CommandRunner
    private let selfPID: Int
    private let nameResolver: @Sendable (Int) -> String   // pid → 进程名（可注入，便于测试）
    public init(runner: CommandRunner = ShellRunner(),
                selfPID: Int = Int(getpid()),
                nameResolver: @escaping @Sendable (Int) -> String = { OptimizationService.nameForPID($0) }) {
        self.runner = runner
        self.selfPID = selfPID
        self.nameResolver = nameResolver
    }

    /// 系统关键进程：绝不结束（会导致掉登录/崩溃）。
    static let protectedNames: Set<String> = [
        "WindowServer", "kernel_task", "launchd", "loginwindow", "Dock", "Finder",
        "SystemUIServer", "ControlCenter", "Spotlight", "coreaudiod", "mds", "mds_stores",
        "WindowManager", "PerfMon", "backboardd", "logind"
    ]

    /// 纯函数：判断某进程是否"受保护、绝不可结束"。
    /// 系统关键进程 / com.apple.* / 自身 / pid<=1 → 受保护。
    public static func isProtectedName(_ name: String, pid: Int, selfPID: Int) -> Bool {
        if pid == selfPID || pid <= 1 { return true }
        if protectedNames.contains(name) { return true }
        if name.hasPrefix("com.apple.") { return true }
        return false
    }

    /// 薄层：由 pid 解析进程名（取可执行文件名）。解析失败返回空串。
    public static func nameForPID(_ pid: Int) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-p", "\(pid)", "-o", "comm="]
        let pipe = Pipe()
        p.standardOutput = pipe
        do { try p.run() } catch { return "" }
        let d = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let full = String(decoding: d, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return full.isEmpty ? "" : (full as NSString).lastPathComponent
    }

    /// 纯函数：从按内存排序的进程里挑出"可安全结束的大型应用"。
    /// 排除：系统关键进程、com.apple.* 系统进程、自身、低于 minMB 的进程。取前 limit 个。
    public static func killableMemoryHogs(_ procs: [ProcessSample], selfPID: Int,
                                          limit: Int = 3, minMB: Int = 400) -> [ProcessSample] {
        var out: [ProcessSample] = []
        for p in procs {
            if p.pid == selfPID { continue }
            if p.memMB < minMB { continue }
            if p.name.hasPrefix("com.apple.") { continue }
            if protectedNames.contains(p.name) { continue }
            out.append(p)
            if out.count >= limit { break }
        }
        return out
    }

    /// 纯函数：根据当前指标，建议默认勾选的动作集合。
    public static func suggestedActions(_ m: Metrics) -> [BoostAction] {
        // 注意：.killProcesses 不再自动勾选——结束进程会丢数据，必须由用户主动选择。
        var actions: [BoostAction] = []
        if m.swapPercent >= 50 || m.memPercent >= 80 { actions.append(.purgeMemory) }
        actions.append(.clearCaches)
        if m.cpuPercent >= 50 { actions.append(.reduceEffects) }
        return actions
    }

    /// 执行单个动作（killPids 仅 killProcesses 用到）。
    public func execute(_ action: BoostAction, killPids: [Int] = []) -> BoostStepResult {
        switch action {
        case .killProcesses:
            // 安全网：在最底层强制排除系统关键进程（WindowServer/kernel/com.apple.*）与自身。
            // 即使调用方误传 WindowServer 的 pid，这里也会拒杀，避免杀掉图形服务导致死机。
            let targets = killPids.filter { pid in
                let name = nameResolver(pid)
                if name.isEmpty { return false }    // 解析失败 → 宁可不杀
                return !Self.isProtectedName(name, pid: pid, selfPID: selfPID)
            }
            guard !targets.isEmpty else {
                return BoostStepResult(action: action, ok: true, message: "无可安全结束的进程（已排除系统进程与自身），跳过")
            }
            var killed = 0
            for pid in targets {
                let (ok, _) = runner.run("/bin/kill", ["\(pid)"])
                if ok { killed += 1 }
            }
            return BoostStepResult(action: action, ok: killed > 0,
                                   message: "已结束 \(killed)/\(targets.count) 个进程")
        case .clearCaches:
            let home = NSHomeDirectory()
            let (ok, _) = runner.run("/bin/sh", ["-c", "rm -rf \(home)/Library/Caches/* 2>/dev/null; echo done"])
            return BoostStepResult(action: action, ok: ok, message: ok ? "缓存已清理" : "清理失败")
        case .reduceEffects:
            let (ok, _) = runner.run("/usr/bin/defaults",
                                     ["write", "com.apple.universalaccess", "reduceTransparency", "-bool", "true"])
            return BoostStepResult(action: action, ok: ok,
                                   message: ok ? "已开启减少透明度（可还原）" : "设置失败")
        case .purgeMemory:
            // purge 需 root；用 osascript 弹一次管理员授权。
            let (ok, out) = runner.run("/usr/bin/osascript",
                ["-e", "do shell script \"purge\" with administrator privileges"])
            return BoostStepResult(action: action, ok: ok,
                                   message: ok ? "内存已释放" : "已取消或失败：\(out.prefix(40))")
        }
    }

    /// 还原可逆动作（目前：恢复透明度）。
    public func restoreEffects() -> BoostStepResult {
        let (ok, _) = runner.run("/usr/bin/defaults",
                                 ["write", "com.apple.universalaccess", "reduceTransparency", "-bool", "false"])
        return BoostStepResult(action: .reduceEffects, ok: ok,
                               message: ok ? "已恢复透明度" : "恢复失败")
    }
}
