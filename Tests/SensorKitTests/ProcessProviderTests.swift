import XCTest
@testable import SensorKit

final class ProcessProviderTests: XCTestCase {
    func testParseCPUAndMemory() {
        // 列：PID %CPU RSS(KB) COMM
        let out = """
          PID %CPU    RSS COMM
          158 44.0 716800 WindowServer
          3187 41.2 745472 Claude Helper
          2263 9.3 2031616 Telegram
        """
        let r = ProcessProvider.parse(out, limit: 8)
        XCTAssertEqual(r.count, 3)
        XCTAssertEqual(r[0], ProcessSample(pid: 158, name: "WindowServer", cpuPercent: 44, memMB: 700))
        XCTAssertEqual(r[1].name, "Claude Helper")
        XCTAssertEqual(r[1].cpuPercent, 41)
        XCTAssertEqual(r[2].memMB, 1984)   // 2031616 KB / 1024
    }
    func testParseRespectsLimit() {
        let out = """
          PID %CPU RSS COMM
          1 10.0 1024 a
          2 9.0 2048 b
          3 8.0 4096 c
        """
        XCTAssertEqual(ProcessProvider.parse(out, limit: 2).count, 2)
    }
    func testParseIgnoresMalformedLines() {
        let out = """
          PID %CPU RSS COMM
          garbage line
          158 44.0 102400 WindowServer
        """
        let r = ProcessProvider.parse(out, limit: 8)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].pid, 158)
        XCTAssertEqual(r[0].memMB, 100)
    }
}
