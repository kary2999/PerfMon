import XCTest
@testable import SensorKit

final class PercentTests: XCTestCase {
    func testRatioRoundsToInt() {
        XCTAssertEqual(Percent.ratio(used: 21, total: 24), 88)
    }
    func testRatioFullIs100() {
        XCTAssertEqual(Percent.ratio(used: 16, total: 16), 100)
    }
    func testRatioZeroTotalNoCrash() {
        XCTAssertEqual(Percent.ratio(used: 0, total: 0), 0)
    }
}
