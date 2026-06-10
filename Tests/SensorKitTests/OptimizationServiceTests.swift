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
        XCTAssertTrue(actions.contains(.killProcesses))
        XCTAssertTrue(actions.contains(.clearCaches))
        XCTAssertTrue(actions.contains(.reduceEffects))
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
