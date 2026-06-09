import XCTest
@testable import SensorKit

final class DiagnosisEngineTests: XCTestCase {
    func testSwapHighIsCriticalAndFirst() {
        let m = Metrics(cpuPercent: 30, memPercent: 70, swapPercent: 94,
                        load1: 3, uptimeDays: 2,
                        temps: Temperatures(cpu: 60, gpu: nil), topProcesses: [])
        let issues = DiagnosisEngine.analyze(m)
        XCTAssertEqual(issues.first?.code, "swap_high")
        XCTAssertEqual(issues.first?.severity, .critical)
        XCTAssertEqual(issues.first?.suggestedAction, "purge")
    }

    func testHighProcessProducesKillSuggestion() {
        let m = Metrics(cpuPercent: 50, memPercent: 50, swapPercent: 10,
                        load1: 3, uptimeDays: 1,
                        temps: Temperatures(cpu: 60, gpu: nil),
                        topProcesses: [ProcessSample(pid: 3187, name: "Claude Helper", cpuPercent: 41)])
        let issues = DiagnosisEngine.analyze(m)
        XCTAssertTrue(issues.contains { $0.code == "proc_high_3187" && $0.suggestedAction == "kill" })
    }

    func testUptimeWarning() {
        let m = Metrics(cpuPercent: 10, memPercent: 30, swapPercent: 0,
                        load1: 1, uptimeDays: 21,
                        temps: Temperatures(cpu: 45, gpu: nil), topProcesses: [])
        let issues = DiagnosisEngine.analyze(m)
        XCTAssertTrue(issues.contains { $0.code == "uptime_high" && $0.severity == .info })
    }

    func testHealthySystemNoCritical() {
        let m = Metrics(cpuPercent: 8, memPercent: 40, swapPercent: 0,
                        load1: 1, uptimeDays: 1,
                        temps: Temperatures(cpu: 42, gpu: nil), topProcesses: [])
        let issues = DiagnosisEngine.analyze(m)
        XCTAssertFalse(issues.contains { $0.severity == .critical })
    }
}
