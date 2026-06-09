import XCTest
@testable import SensorKit

final class SwapStatsTests: XCTestCase {
    func testBytesToGB() {
        XCTAssertEqual(SwapStats.toGB(bytes: 16_106_127_360), 15.0, accuracy: 0.05)
    }
    func testZeroBytes() {
        XCTAssertEqual(SwapStats.toGB(bytes: 0), 0.0, accuracy: 0.001)
    }
}
