import XCTest
@testable import SensorKit

final class SemVerTests: XCTestCase {
    func testNewerMinor() { XCTAssertTrue(SemVer.isNewer("1.6.0", than: "1.5.1")) }
    func testNewerPatch() { XCTAssertTrue(SemVer.isNewer("1.5.2", than: "1.5.1")) }
    func testNotNewerSame() { XCTAssertFalse(SemVer.isNewer("1.6.0", than: "1.6.0")) }
    func testNotNewerOlder() { XCTAssertFalse(SemVer.isNewer("1.4.9", than: "1.5.0")) }
    func testHandlesVPrefix() { XCTAssertTrue(SemVer.isNewer("v2.0.0", than: "1.9.9")) }
    func testDifferentLengths() {
        XCTAssertTrue(SemVer.isNewer("1.6", than: "1.5.9"))
        XCTAssertFalse(SemVer.isNewer("1.6", than: "1.6.0"))
    }
    func testMajorBeatsMinor() { XCTAssertTrue(SemVer.isNewer("2.0.0", than: "1.99.99")) }
}
