import XCTest
@testable import SensorKit

/// 测试用 mock：记录被调用的命令，不真的执行。
final class MockRunner: CommandRunner, @unchecked Sendable {
    var calls: [(String, [String])] = []
    var succeed = true
    func run(_ launchPath: String, _ args: [String]) -> (Bool, String) {
        calls.append((launchPath, args))
        return (succeed, "mock")
    }
}

final class OptimizationServiceTests: XCTestCase {
    func testSuggestedActionsForBadMetrics() {
        let bad = Metrics(cpuPercent: 82, memPercent: 88, swapPercent: 94,
                          load1: 7, uptimeDays: 21,
                          temps: Temperatures(cpu: 78, gpu: nil),
                          topProcesses: [ProcessSample(pid: 1, name: "X", cpuPercent: 50)])
        let actions = OptimizationService.suggestedActions(bad)
        XCTAssertTrue(actions.contains(.purgeMemory))
        XCTAssertFalse(actions.contains(.killProcesses))   // 结束进程不再自动勾选（会丢数据）
        XCTAssertTrue(actions.contains(.clearCaches))
        XCTAssertTrue(actions.contains(.reduceEffects))
    }

    func testProtectedSystemProcesses() {
        // 系统关键进程、com.apple.*、自身、pid<=1 → 受保护，绝不结束
        XCTAssertTrue(OptimizationService.isProtectedName("WindowServer", pid: 157, selfPID: 999))
        XCTAssertTrue(OptimizationService.isProtectedName("kernel_task", pid: 0, selfPID: 999))
        XCTAssertTrue(OptimizationService.isProtectedName("com.apple.Virtualization.VirtualMachine", pid: 500, selfPID: 999))
        XCTAssertTrue(OptimizationService.isProtectedName("Finder", pid: 300, selfPID: 999))
        XCTAssertTrue(OptimizationService.isProtectedName("PerfMon", pid: 999, selfPID: 999))   // 自身
        XCTAssertTrue(OptimizationService.isProtectedName("Anything", pid: 1, selfPID: 999))    // pid<=1
        // 第三方应用 → 不受保护，可结束
        XCTAssertFalse(OptimizationService.isProtectedName("Google Chrome Helper", pid: 800, selfPID: 999))
        XCTAssertFalse(OptimizationService.isProtectedName("Cursor", pid: 801, selfPID: 999))
    }

    func testKillProcessesInvokesKillPerPid() {
        let mock = MockRunner()
        let svc = OptimizationService(runner: mock)
        let r = svc.execute(.killProcesses, killPids: [100, 200])
        XCTAssertTrue(r.ok)
        XCTAssertEqual(mock.calls.count, 2)
        XCTAssertEqual(mock.calls[0].0, "/bin/kill")
        XCTAssertEqual(mock.calls[0].1, ["100"])
        XCTAssertEqual(mock.calls[1].1, ["200"])
    }

    func testKillNeverKillsSelf() {
        let mock = MockRunner()
        let svc = OptimizationService(runner: mock, selfPID: 100)
        let r = svc.execute(.killProcesses, killPids: [100, 200])  // 100 = 自身
        XCTAssertTrue(r.ok)
        XCTAssertEqual(mock.calls.count, 1)            // 只 kill 了 200
        XCTAssertEqual(mock.calls[0].1, ["200"])
    }

    func testKillOnlySelfSkips() {
        let mock = MockRunner()
        let svc = OptimizationService(runner: mock, selfPID: 100)
        let r = svc.execute(.killProcesses, killPids: [100])       // 只有自身
        XCTAssertTrue(r.ok)
        XCTAssertEqual(mock.calls.count, 0)            // 不调用 kill
    }

    func testKillWithNoPidsSkips() {
        let mock = MockRunner()
        let svc = OptimizationService(runner: mock)
        let r = svc.execute(.killProcesses, killPids: [])
        XCTAssertTrue(r.ok)
        XCTAssertEqual(mock.calls.count, 0)   // 没有要结束的进程，不调用 kill
    }

    func testReduceEffectsWritesDefaults() {
        let mock = MockRunner()
        let svc = OptimizationService(runner: mock)
        _ = svc.execute(.reduceEffects)
        XCTAssertEqual(mock.calls.first?.0, "/usr/bin/defaults")
        XCTAssertTrue(mock.calls.first?.1.contains("reduceTransparency") ?? false)
    }

    func testKillableMemoryHogsExcludesSystemAndSelf() {
        let procs = [
            ProcessSample(pid: 1, name: "WindowServer", cpuPercent: 5, memMB: 2000),               // 系统关键 → 排除
            ProcessSample(pid: 2, name: "com.apple.Virtualization.VirtualMachine", cpuPercent: 5, memMB: 1500), // com.apple.* → 排除
            ProcessSample(pid: 3, name: "Google Chrome Helper", cpuPercent: 5, memMB: 900),         // ✓
            ProcessSample(pid: 4, name: "PerfMon", cpuPercent: 5, memMB: 800),                       // 自身名 → 排除
            ProcessSample(pid: 5, name: "Cursor", cpuPercent: 5, memMB: 700),                        // ✓
            ProcessSample(pid: 6, name: "Tiny", cpuPercent: 5, memMB: 100),                          // < minMB → 排除
        ]
        let hogs = OptimizationService.killableMemoryHogs(procs, selfPID: 999, limit: 3, minMB: 400)
        XCTAssertEqual(hogs.map { $0.pid }, [3, 5])
    }

    func testKillableMemoryHogsExcludesSelfPID() {
        let procs = [ProcessSample(pid: 100, name: "Chrome", cpuPercent: 5, memMB: 900)]
        XCTAssertTrue(OptimizationService.killableMemoryHogs(procs, selfPID: 100).isEmpty)
    }

    func testActionMetadata() {
        XCTAssertTrue(BoostAction.killProcesses.isRisky)
        XCTAssertTrue(BoostAction.reduceEffects.isReversible)
        XCTAssertFalse(BoostAction.purgeMemory.isReversible)
    }
}
