import XCTest
@testable import SensorKit

final class MetricsTests: XCTestCase {
    func testCriticalPressureLowScore() {
        // 内存压力严重 + CPU 高 → 健康分应很低。
        let bad = Metrics(cpuPercent: 82, memPercent: 88, swapPercent: 94,
                          load1: 7.4, uptimeDays: 21,
                          temps: Temperatures(cpu: 78, gpu: 71), topProcesses: [],
                          pressure: .critical)
        XCTAssertLessThan(Metrics.healthScore(bad), 50)
        XCTAssertTrue((0...100).contains(Metrics.healthScore(bad)))
    }
    func testNormalPressureHighScore() {
        let good = Metrics(cpuPercent: 8, memPercent: 40, swapPercent: 0,
                           load1: 1.0, uptimeDays: 1,
                           temps: Temperatures(cpu: 45, gpu: 40), topProcesses: [],
                           pressure: .normal)
        XCTAssertGreaterThan(Metrics.healthScore(good), 80)
    }
    func testSwapHighDoesNotHurtScoreWhenPressureNormal() {
        // 关键：Swap 94% 但压力正常 → 健康分仍然高（Swap 不再扣分）。
        let m = Metrics(cpuPercent: 10, memPercent: 60, swapPercent: 94,
                        load1: 2, uptimeDays: 3,
                        temps: Temperatures(cpu: 50, gpu: nil), topProcesses: [],
                        pressure: .normal)
        XCTAssertGreaterThan(Metrics.healthScore(m), 90)
    }
}
