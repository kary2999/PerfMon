import XCTest
@testable import SensorKit

final class CPUUsageTests: XCTestCase {
    func testBusyOverTotal() {
        let t0 = CPUTicks(user: 100, system: 50, idle: 850, nice: 0)   // total 1000
        let t1 = CPUTicks(user: 200, system: 100, idle: 1700, nice: 0) // busyΔ150 / totalΔ1000
        XCTAssertEqual(CPUUsage.percent(previous: t0, current: t1), 15)
    }
    func testNoDeltaIsZero() {
        let t = CPUTicks(user: 200, system: 100, idle: 1700, nice: 0)
        XCTAssertEqual(CPUUsage.percent(previous: t, current: t), 0)
    }
}
