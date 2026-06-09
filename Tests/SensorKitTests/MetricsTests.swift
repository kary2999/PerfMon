import XCTest
@testable import SensorKit

final class MetricsTests: XCTestCase {
    func testHighLoadLowScore() {
        let bad = Metrics(cpuPercent: 82, memPercent: 88, swapPercent: 94,
                          load1: 7.4, uptimeDays: 21,
                          temps: Temperatures(cpu: 78, gpu: 71), topProcesses: [])
        XCTAssertLessThan(Metrics.healthScore(bad), 50)
        XCTAssertTrue((0...100).contains(Metrics.healthScore(bad)))
    }
    func testLowLoadHighScore() {
        let good = Metrics(cpuPercent: 8, memPercent: 40, swapPercent: 0,
                           load1: 1.0, uptimeDays: 1,
                           temps: Temperatures(cpu: 45, gpu: 40), topProcesses: [])
        XCTAssertGreaterThan(Metrics.healthScore(good), 80)
    }
}
