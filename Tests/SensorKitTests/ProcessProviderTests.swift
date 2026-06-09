import XCTest
@testable import SensorKit

final class ProcessProviderTests: XCTestCase {
    func testParseSkipsHeaderAndKeepsOrder() {
        let out = """
          PID %CPU COMM
          158 44.0 WindowServer
          3187 41.2 Claude Helper
          2263 9.3 Telegram
        """
        let r = ProcessProvider.parse(out, limit: 8)
        XCTAssertEqual(r.count, 3)
        XCTAssertEqual(r[0], ProcessSample(pid: 158, name: "WindowServer", cpuPercent: 44))
        XCTAssertEqual(r[1], ProcessSample(pid: 3187, name: "Claude Helper", cpuPercent: 41))
        XCTAssertEqual(r[2].name, "Telegram")
    }
    func testParseRespectsLimit() {
        let out = """
          PID %CPU COMM
          1 10.0 a
          2 9.0 b
          3 8.0 c
        """
        XCTAssertEqual(ProcessProvider.parse(out, limit: 2).count, 2)
    }
    func testParseIgnoresMalformedLines() {
        let out = """
          PID %CPU COMM
          garbage line here
          158 44.0 WindowServer
        """
        let r = ProcessProvider.parse(out, limit: 8)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].pid, 158)
    }
}
