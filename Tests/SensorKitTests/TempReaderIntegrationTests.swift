import XCTest
@testable import SensorKit

final class TempReaderIntegrationTests: XCTestCase {
    // 集成观察用例：打印真实读数，不做硬断言（不同芯片/权限下结果不同）。
    func testPrintRealSensors() {
        let raw = TempReader().readAll()
        print("读到 \(raw.count) 个温度传感器")
        for (n, v) in raw.prefix(8) { print("  \(n): \(v)°C") }
        let cls = TempClassifier.classify(raw)
        print("分类后 → CPU: \(cls.cpu.map{"\($0)°C"} ?? "不可用"), GPU: \(cls.gpu.map{"\($0)°C"} ?? "不可用")")
        XCTAssertTrue(true)
    }
}
