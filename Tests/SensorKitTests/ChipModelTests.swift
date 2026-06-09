import XCTest
@testable import SensorKit

final class ChipModelTests: XCTestCase {
    func testM1() { XCTAssertEqual(ChipModel.parse("Apple M1"), .m1) }
    func testM2Pro() { XCTAssertEqual(ChipModel.parse("Apple M2 Pro"), .m2) }
    func testM3() { XCTAssertEqual(ChipModel.parse("Apple M3"), .m3) }
    func testM4Max() { XCTAssertEqual(ChipModel.parse("Apple M4 Max"), .m4) }
    func testM5() { XCTAssertEqual(ChipModel.parse("Apple M5"), .m5) }
    func testIntelUnknown() { XCTAssertEqual(ChipModel.parse("Intel Core i7"), .unknown) }
    func testFutureUnknown() { XCTAssertEqual(ChipModel.parse("Apple M9"), .unknown) }
}
