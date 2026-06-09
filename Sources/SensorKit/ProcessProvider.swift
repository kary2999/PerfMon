import Foundation

/// 进程采集：调用 `ps` 取按 CPU 排序的进程列表。
/// 解析逻辑做成纯函数 `parse` 便于单测；执行 `ps` 的部分是薄层。
public struct ProcessProvider {
    public init() {}

    /// 纯函数：解析 `ps -Aceo pid,pcpu,comm -r` 的输出为进程样本（取前 limit 个）。
    /// 输出形如：
    /// ```
    ///   PID  %CPU COMM
    ///   3187 41.2 Claude Helper
    ///   158  44.0 WindowServer
    /// ```
    public static func parse(_ output: String, limit: Int = 8) -> [ProcessSample] {
        var result: [ProcessSample] = []
        let lines = output.split(separator: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // 跳过表头
            if trimmed.hasPrefix("PID") { continue }
            // 拆出前两列（pid、pcpu），剩余全部作为进程名
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 3,
                  let pid = Int(parts[0]),
                  let pcpu = Double(parts[1]) else { continue }
            let name = parts[2...].joined(separator: " ")
            result.append(ProcessSample(pid: pid, name: name, cpuPercent: Int(pcpu.rounded())))
            if result.count >= limit { break }
        }
        return result
    }

    /// 薄层：执行 ps 并解析。
    public func top(limit: Int = 8) -> [ProcessSample] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-Aceo", "pid,pcpu,comm", "-r"]
        let pipe = Pipe()
        p.standardOutput = pipe
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            let out = String(decoding: data, as: UTF8.self)
            return Self.parse(out, limit: limit)
        } catch {
            return []
        }
    }
}
