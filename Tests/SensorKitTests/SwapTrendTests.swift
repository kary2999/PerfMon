import XCTest
@testable import SensorKit

final class SwapTrendTests: XCTestCase {
    func testGrowthPerMinute() {
        // 0→6GB，6 个采样、间隔 6s → 跨度 30s → 每分钟 +12GB
        let g = SwapTrend.growthPerMinute([0, 1, 2, 3, 4, 6], sampleIntervalSec: 6)
        XCTAssertEqual(g, 12.0, accuracy: 0.01)
    }
    func testFlatIsZero() {
        XCTAssertEqual(SwapTrend.growthPerMinute([5, 5, 5], sampleIntervalSec: 6), 0, accuracy: 0.01)
    }
    func testSingleSample() {
        XCTAssertEqual(SwapTrend.growthPerMinute([5], sampleIntervalSec: 6), 0)
    }
    func testDirection() {
        XCTAssertEqual(SwapTrend.direction(growthPerMin: 1.0), .rising)
        XCTAssertEqual(SwapTrend.direction(growthPerMin: -0.5), .falling)
        XCTAssertEqual(SwapTrend.direction(growthPerMin: 0.0), .stable)
    }
}
