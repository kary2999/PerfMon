import XCTest
@testable import SensorKit

final class TempClassifierTests: XCTestCase {
    func testClassifyAndAggregate() {
        let sensors = [
            ("pACC MTR Temp Sensor0", 78.0),   // 性能核 → CPU
            ("eACC MTR Temp Sensor1", 60.0),   // 能效核 → CPU
            ("GPU MTR Temp Sensor2", 71.0),    // GPU
            ("PMU tdev1", 40.0),               // 无关 → 忽略
        ]
        let r = TempClassifier.classify(sensors)
        XCTAssertEqual(r.cpu, 78.0)            // CPU 取最大
        XCTAssertEqual(r.gpu, 71.0)
    }
    func testUnknownDegradesToNil() {
        let r = TempClassifier.classify([("Unknown XYZ", 50.0)])
        XCTAssertNil(r.cpu)                    // 不编造
        XCTAssertNil(r.gpu)
    }
    // Apple Silicon（M3 实测）：die 温度 tdie/tcal 归 CPU，电池/NAND 忽略，GPU 无传感器 → nil。
    func testAppleSiliconDieSensors() {
        let sensors = [
            ("PMU tdie5", 49.5),
            ("PMU2 tcal", 51.9),
            ("PMU tdev6", 34.7),         // 设备温度，忽略
            ("NAND CH0 temp", 38.0),     // 固态硬盘，忽略
            ("gas gauge battery", 29.0), // 电池，忽略
        ]
        let r = TempClassifier.classify(sensors)
        XCTAssertEqual(r.cpu, 51.9)              // 取 die/tcal 最大值
        XCTAssertNil(r.gpu)                      // 此芯片无 GPU 专属传感器 → 不可用
    }
}
