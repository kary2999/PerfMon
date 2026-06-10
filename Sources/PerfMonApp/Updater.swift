import AppKit
import SensorKit

struct ReleaseInfo {
    let version: String      // 如 "1.6.0"（已去 v 前缀）
    let zipURL: URL
    let notes: String
}

/// 应用内自更新：查 GitHub 最新 Release → 比版本 → 用户确认 → 下载替换重启。
/// 由 App 自身下载（URLSession 不加 quarantine）+ 安装时 `xattr -cr`，免去手动授权。
@MainActor
enum Updater {
    static let repo = "kary2999/PerfMon"

    /// 检查最新版本。silent=true 时无更新/失败都不打扰用户。
    static func check(silent: Bool) {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 12
        URLSession.shared.dataTask(with: req) { data, _, _ in
            let info = parse(data)
            DispatchQueue.main.async {
                guard let info else {
                    if !silent { alert("检查更新失败", "无法连接 GitHub，请稍后再试。") }
                    return
                }
                if SemVer.isNewer(info.version, than: AppInfo.version) {
                    promptUpdate(info)
                } else if !silent {
                    alert("已是最新版本", "当前 v\(AppInfo.version) 已是最新。")
                }
            }
        }.resume()
    }

    private static func parse(_ data: Data?) -> ReleaseInfo? {
        guard let data,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = obj["tag_name"] as? String,
              let assets = obj["assets"] as? [[String: Any]] else { return nil }
        let notes = (obj["body"] as? String) ?? ""
        guard let zip = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".zip") == true }),
              let s = zip["browser_download_url"] as? String, let zipURL = URL(string: s) else { return nil }
        return ReleaseInfo(version: tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")),
                           zipURL: zipURL, notes: notes)
    }

    private static func promptUpdate(_ info: ReleaseInfo) {
        let a = NSAlert()
        a.messageText = "发现新版本 v\(info.version)"
        let trimmed = info.notes.split(separator: "\n").prefix(8).joined(separator: "\n")
        a.informativeText = "当前 v\(AppInfo.version)。\n\n更新内容：\n\(trimmed.isEmpty ? "（无说明）" : trimmed)\n\n是否现在升级？升级会自动下载并重启。"
        a.addButton(withTitle: "升级")
        a.addButton(withTitle: "稍后")
        if a.runModal() == .alertFirstButtonReturn { download(info) }
    }

    private static func download(_ info: ReleaseInfo) {
        let progress = NSAlert()
        progress.messageText = "正在下载 v\(info.version)…"
        progress.informativeText = "下载完成后会自动替换并重启，请稍候。"
        // 异步下载，不阻塞；下载完在主线程安装
        URLSession.shared.downloadTask(with: info.zipURL) { tmpURL, _, err in
            DispatchQueue.main.async {
                guard let tmpURL, err == nil else {
                    alert("下载失败", "请检查网络后重试。"); return
                }
                install(zipTmp: tmpURL)
            }
        }.resume()
    }

    /// 解压 → 写安装脚本（等本进程退出 → 替换 → 去 quarantine → 重启）→ 退出本应用。
    private static func install(zipTmp: URL) {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("PerfMonUpdate-\(getpid())")
        try? fm.removeItem(at: work)
        try? fm.createDirectory(at: work, withIntermediateDirectories: true)
        let zipDst = work.appendingPathComponent("update.zip")
        try? fm.removeItem(at: zipDst)
        do { try fm.moveItem(at: zipTmp, to: zipDst) } catch { alert("安装失败", "无法准备更新文件。"); return }

        // 解压
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-x", "-k", zipDst.path, work.path]
        do { try unzip.run(); unzip.waitUntilExit() } catch { alert("安装失败", "解压失败。"); return }
        guard unzip.terminationStatus == 0,
              let newApp = findApp(in: work) else { alert("安装失败", "更新包内未找到 App。"); return }

        let current = Bundle.main.bundlePath
        let pid = getpid()
        let script = work.appendingPathComponent("install.sh")
        let sh = """
        #!/bin/bash
        while kill -0 \(pid) 2>/dev/null; do sleep 0.3; done
        rm -rf "\(current)"
        /usr/bin/ditto "\(newApp)" "\(current)"
        /usr/bin/xattr -cr "\(current)"
        sleep 0.3
        open "\(current)"
        """
        do { try sh.write(to: script, atomically: true, encoding: .utf8) } catch { alert("安装失败", "无法写入安装脚本。"); return }

        // 后台分离运行安装脚本，然后退出本应用
        let runner = Process()
        runner.executableURL = URL(fileURLWithPath: "/bin/bash")
        runner.arguments = ["-c", "nohup bash \"\(script.path)\" >/dev/null 2>&1 &"]
        do { try runner.run() } catch { alert("安装失败", "无法启动安装程序。"); return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { NSApp.terminate(nil) }
    }

    private static func findApp(in dir: URL) -> String? {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: dir.path) else { return nil }
        if let app = items.first(where: { $0.hasSuffix(".app") }) {
            return dir.appendingPathComponent(app).path
        }
        return nil
    }

    private static func alert(_ title: String, _ msg: String) {
        let a = NSAlert(); a.messageText = title; a.informativeText = msg
        a.addButton(withTitle: "好"); a.runModal()
    }
}
