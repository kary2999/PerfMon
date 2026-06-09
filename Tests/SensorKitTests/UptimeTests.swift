import XCTest
@testable import SensorKit

final class UptimeTests: XCTestCase {
    func test21DaysFloor() {
        XCTAssertEqual(Uptime.days(bootEpoch: 1_000_000, nowEpoch: 1_000_000 + 86_400 * 21 + 5), 21)
    }
    func testLessThanADay() {
        XCTAssertEqual(Uptime.days(bootEpoch: 1_000_000, nowEpoch: 1_000_000 + 100), 0)
    }
}
