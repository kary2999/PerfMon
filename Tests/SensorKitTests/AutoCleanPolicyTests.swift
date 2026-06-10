import XCTest
@testable import SensorKit

final class AutoCleanPolicyTests: XCTestCase {
    func testTriggersWhenOverThresholdAndHourPassed() {
        XCTAssertTrue(AutoCleanPolicy.shouldClean(
            memUsedGB: 6, thresholdGB: 5, secondsSinceLastClean: 3600, enabled: true))
    }
    func testNotWhenUnderThreshold() {
        XCTAssertFalse(AutoCleanPolicy.shouldClean(
            memUsedGB: 4.9, thresholdGB: 5, secondsSinceLastClean: 99999, enabled: true))
    }
    func testNotWithinOneHour() {
        XCTAssertFalse(AutoCleanPolicy.shouldClean(
            memUsedGB: 8, thresholdGB: 5, secondsSinceLastClean: 3599, enabled: true))
    }
    func testNotWhenDisabled() {
        XCTAssertFalse(AutoCleanPolicy.shouldClean(
            memUsedGB: 8, thresholdGB: 5, secondsSinceLastClean: 99999, enabled: false))
    }
    func testIntervalIsOneHour() {
        XCTAssertEqual(AutoCleanPolicy.minIntervalSeconds, 3600)
    }
}
