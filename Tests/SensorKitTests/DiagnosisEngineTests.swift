import XCTest
@testable import SensorKit

final class DiagnosisEngineTests: XCTestCase {
    func testCriticalPressureIsCriticalAndFirst() {
        let m = Metrics(cpuPercent: 30, memPercent: 70, swapPercent: 50,
                        load1: 3, uptimeDays: 2,
                        temps: Temperatures(cpu: 60, gpu: nil), topProcesses: [],
                        pressure: .critical)
        let issues = DiagnosisEngine.analyze(m)
        XCTAssertEqual(issues.first?.code, "mem_pressure")
        XCTAssertEqual(issues.first?.severity, .critical)
        XCTAssertEqual(issues.first?.suggestedAction, "purge")
    }

    func testSwapHighButNormalPressureIsReassuringInfo() {
        // Swap 94% 但压力正常 → 给"无需清理"的 info，不报严重。
        let m = Metrics(cpuPercent: 20, memPercent: 60, swapPercent: 94,
                        load1: 2, uptimeDays: 1,
                        temps: Temperatures(cpu: 50, gpu: nil), topProcesses: [],
                        pressure: .normal)
        let issues = DiagnosisEngine.analyze(m)
        XCTAssertFalse(issues.contains { $0.severity == .critical })
        XCTAssertTrue(issues.contains { $0.code == "swap_ok" && $0.severity == .info })
    }

    func testHighProcessProducesKillSuggestion() {
        let m = Metrics(cpuPercent: 50, memPercent: 50, swapPercent: 10,
                        load1: 3, uptimeDays: 1,
                        temps: Temperatures(cpu: 60, gpu: nil),
                        topProcesses: [ProcessSample(pid: 3187, name: "Claude Helper", cpuPercent: 41)],
                        pressure: .normal)
        let issues = DiagnosisEngine.analyze(m)
        XCTAssertTrue(issues.contains { $0.code == "proc_high_3187" && $0.suggestedAction == "kill" })
    }

    func testUptimeWarning() {
        let m = Metrics(cpuPercent: 10, memPercent: 30, swapPercent: 0,
                        load1: 1, uptimeDays: 21,
                        temps: Temperatures(cpu: 45, gpu: nil), topProcesses: [],
                        pressure: .normal)
        let issues = DiagnosisEngine.analyze(m)
        XCTAssertTrue(issues.contains { $0.code == "uptime_high" && $0.severity == .info })
    }

    func testHealthySystemNoCritical() {
        let m = Metrics(cpuPercent: 8, memPercent: 40, swapPercent: 0,
                        load1: 1, uptimeDays: 1,
                        temps: Temperatures(cpu: 42, gpu: nil), topProcesses: [],
                        pressure: .normal)
        let issues = DiagnosisEngine.analyze(m)
        XCTAssertFalse(issues.contains { $0.severity == .critical })
    }
}
