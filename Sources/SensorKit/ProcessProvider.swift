import Foundation

/// 进程采集：调用 `ps` 取进程列表（含 CPU 与内存 RSS）。
/// 解析逻辑做成纯函数 `parse` 便于单测；执行 `ps` 的部分是薄层。
public struct ProcessProvider {
    public enum SortKey { case cpu, memory }

    public init() {}

    /// 纯函数：解析 `ps -Aceo pid,pcpu,rss,comm` 的输出为进程样本（取前 limit 个）。
    /// 列：PID  %CPU  RSS(KB)  COMM
    public static func parse(_ output: String, limit: Int = 8) -> [ProcessSample] {
        var result: [ProcessSample] = []
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("PID") { continue }   // 表头
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 4,
                  let pid = Int(parts[0]),
                  let pcpu = Double(parts[1]),
                  let rssKB = Int(parts[2]) else { continue }
            let name = parts[3...].joined(separator: " ")
            result.append(ProcessSample(pid: pid, name: name,
                                        cpuPercent: Int(pcpu.rounded()),
                                        memMB: rssKB / 1024))
            if result.count >= limit { break }
        }
        return result
    }

    /// 薄层：执行 ps（按 CPU 用 -r，按内存用 -m）并解析。
    public func top(limit: Int = 8, by: SortKey = .cpu) -> [ProcessSample] {
        let sortFlag = (by == .cpu) ? "-r" : "-m"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-Aceo", "pid,pcpu,rss,comm", sortFlag]
        let pipe = Pipe()
        p.standardOutput = pipe
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return Self.parse(String(decoding: data, as: UTF8.self), limit: limit)
        } catch {
            return []
        }
    }
}
