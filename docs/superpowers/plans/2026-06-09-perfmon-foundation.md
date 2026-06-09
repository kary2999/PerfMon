# PerfMon Foundation Implementation Plan (Plan 1 of N)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 搭好标准 SwiftPM 工程骨架，实现 SensorKit 核心指标采集（CPU/内存/Swap/负载/开机时长）与跨芯片温度读取，并用毛玻璃「总览」窗口显示真实数据，产出一个能 `swift run PerfMonApp` 跑起来的可用 App。

**Architecture:** 标准 SwiftPM 多 target：核心逻辑 `SensorKit` 库 target（纯函数可单测 + 薄 Provider 层），UI 为 `PerfMonApp` 可执行 target（SwiftUI + AppKit，NSVisualEffectView 毛玻璃），测试为 `SensorKitTests`（XCTest）。系统调用收敛在 `*Provider`/`TempReader`，UI 只读 `AppState`。

**Tech Stack:** Swift 6.0.3、Xcode 16.2、SwiftPM、XCTest、AppKit、SwiftUI、IOKit（`IOHIDEventSystemClient` 私有框架读温度）、mach/host_processor_info、sysctl。

**本机工具链（已实测可用）：**
- Xcode 16.2（16C5032a）已装并 `xcode-select` 指向它；`swift build` / `swift test`（SwiftPM + XCTest）✓ 正常。
- `import AppKit` / `import IOKit` ✓、NSVisualEffectView ✓。
- 开发期用 `swift run PerfMonApp` 启动 App；需要 GUI 预览/正式打包时 `open Package.swift` 用 Xcode。

---

## File Structure

```
CPU_Monitor/
├── Package.swift                       # SwiftPM 清单：3 个 target
├── Sources/
│   ├── SensorKit/                      # 库 target（可测）
│   │   ├── Percent.swift               # 纯函数：占比/取整
│   │   ├── CPUUsage.swift              # 纯函数：两次 tick → CPU%
│   │   ├── CPUProvider.swift           # 薄层：host_processor_info
│   │   ├── MemoryProvider.swift        # 薄层：host_statistics64 + hw.memsize
│   │   ├── SwapProvider.swift          # 薄层：sysctl vm.swapusage
│   │   ├── SystemProvider.swift        # 薄层：getloadavg / kern.boottime
│   │   ├── ChipModel.swift             # 纯函数：brand string → 芯片代次
│   │   ├── TempClassifier.swift        # 纯函数：传感器名 → CPU/GPU 聚合
│   │   ├── TempReader.swift            # 薄层：IOHIDEventSystemClient
│   │   ├── Metrics.swift               # 指标模型 + 健康分
│   │   └── SensorKit.swift             # 门面：snapshot()
│   └── PerfMonApp/                     # 可执行 target（GUI）
│       ├── main.swift                  # NSApplication 入口
│       ├── AppState.swift              # ObservableObject + 采样定时器
│       ├── GlassBackground.swift       # NSVisualEffectView 封装
│       ├── RingView.swift              # 环形仪表
│       ├── SparklineView.swift         # 迷你折线
│       ├── TempGaugeView.swift         # 温度计样式三
│       └── OverviewView.swift          # 总览页
└── Tests/
    └── SensorKitTests/                 # XCTest test target
        ├── PercentTests.swift
        ├── CPUUsageTests.swift
        ├── SwapStatsTests.swift
        ├── UptimeTests.swift
        ├── ChipModelTests.swift
        ├── TempClassifierTests.swift
        └── MetricsTests.swift
```

**职责边界：** UI 只读 `AppState`；所有系统调用收敛在 `*Provider`/`TempReader`；纯计算（Percent/CPUUsage/ChipModel/TempClassifier/Metrics.healthScore）独立可测。

**测试命令统一为：** `swift test`（跑全部）或 `swift test --filter <ClassName>`（跑单个）。

---

## Task 1: SwiftPM 工程骨架 + 第一个纯函数（Percent）+ 毛玻璃冒烟窗口

**Files:**
- Create: `Package.swift`
- Create: `Sources/SensorKit/Percent.swift`
- Create: `Tests/SensorKitTests/PercentTests.swift`
- Create: `Sources/PerfMonApp/main.swift`

- [ ] **Step 1: 写 Package.swift（3 个 target）**

Create `Package.swift`:
```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PerfMon",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "SensorKit"),
        .executableTarget(
            name: "PerfMonApp",
            dependencies: ["SensorKit"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
            ]
        ),
        .testTarget(name: "SensorKitTests", dependencies: ["SensorKit"]),
    ]
)
```

- [ ] **Step 2: 写失败测试（纯函数 Percent）**

Create `Tests/SensorKitTests/PercentTests.swift`:
```swift
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
```

- [ ] **Step 3: 运行测试，确认编译失败**

Run: `swift test --filter PercentTests`
Expected: 编译错误 `cannot find 'Percent' in scope`（符合预期，还没实现）。

- [ ] **Step 4: 实现 Percent 纯函数**

Create `Sources/SensorKit/Percent.swift`:
```swift
import Foundation

/// 纯函数：占比计算，集中处理除零与取整。
public enum Percent {
    /// used/total 的百分比，四舍五入到整数；total<=0 返回 0。
    public static func ratio(used: Double, total: Double) -> Int {
        guard total > 0 else { return 0 }
        return Int((used / total * 100).rounded())
    }
}
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `swift test --filter PercentTests`
Expected: `Executed 3 tests, with 0 failures`。

- [ ] **Step 6: 写最小 App 入口（毛玻璃冒烟窗口）**

Create `Sources/PerfMonApp/main.swift`:
```swift
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    func applicationDidFinishLaunching(_ note: Notification) {
        let content = NSHostingView(rootView: Text("PerfMon 🚀").font(.title).padding(40))
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        let vfx = NSVisualEffectView()
        vfx.material = .hudWindow
        vfx.blendingMode = .behindWindow
        vfx.state = .active
        vfx.frame = window.contentView!.bounds
        vfx.autoresizingMask = [.width, .height]
        content.frame = vfx.bounds
        content.autoresizingMask = [.width, .height]
        vfx.addSubview(content)
        window.contentView = vfx
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
```

- [ ] **Step 7: 构建并运行，确认毛玻璃窗口弹出**

Run: `swift run PerfMonApp`
Expected: 弹出半透明毛玻璃窗口，居中显示 “PerfMon 🚀”。手动关闭窗口后用 Ctrl+C 结束进程。

- [ ] **Step 8: 提交**

```bash
git add Package.swift Sources Tests
git commit -m "feat: SwiftPM 工程骨架 + Percent 纯函数 + 毛玻璃冒烟窗口"
```

---

## Task 2: SensorKit — CPU 占用（纯函数 + Provider）

**Files:**
- Create: `Sources/SensorKit/CPUUsage.swift`
- Create: `Sources/SensorKit/CPUProvider.swift`
- Create: `Tests/SensorKitTests/CPUUsageTests.swift`

- [ ] **Step 1: 写失败测试（CPU% 由两次 tick 快照计算）**

Create `Tests/SensorKitTests/CPUUsageTests.swift`:
```swift
import XCTest
@testable import SensorKit

final class CPUUsageTests: XCTestCase {
    func testBusyOverTotal() {
        let t0 = CPUTicks(user: 100, system: 50, idle: 850, nice: 0)   // total 1000
        let t1 = CPUTicks(user: 200, system: 100, idle: 1700, nice: 0) // busyΔ150 / totalΔ1000
        XCTAssertEqual(CPUUsage.percent(previous: t0, current: t1), 15)
    }
    func testNoDeltaIsZero() {
        let t = CPUTicks(user: 200, system: 100, idle: 1700, nice: 0)
        XCTAssertEqual(CPUUsage.percent(previous: t, current: t), 0)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter CPUUsageTests`
Expected: `cannot find 'CPUTicks' / 'CPUUsage' in scope`。

- [ ] **Step 3: 实现 CPUTicks + CPUUsage 纯函数**

Create `Sources/SensorKit/CPUUsage.swift`:
```swift
import Foundation

/// CPU 累计时间片（跨全部核心求和）。
public struct CPUTicks: Equatable {
    public var user: Double
    public var system: Double
    public var idle: Double
    public var nice: Double
    public init(user: Double, system: Double, idle: Double, nice: Double) {
        self.user = user; self.system = system; self.idle = idle; self.nice = nice
    }
    public var busy: Double { user + system + nice }
    public var total: Double { busy + idle }
}

/// 纯函数：两次快照差值 → 占用百分比。
public enum CPUUsage {
    public static func percent(previous: CPUTicks, current: CPUTicks) -> Int {
        let totalDelta = current.total - previous.total
        let busyDelta = current.busy - previous.busy
        guard totalDelta > 0 else { return 0 }
        return Int((busyDelta / totalDelta * 100).rounded())
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --filter CPUUsageTests`
Expected: `Executed 2 tests, with 0 failures`。

- [ ] **Step 5: 实现 CPUProvider（薄层，取真实 tick）**

Create `Sources/SensorKit/CPUProvider.swift`:
```swift
import Foundation
import Darwin

/// 薄层：通过 host_processor_info 读取全核累计 CPU tick。
public struct CPUProvider {
    public init() {}

    public func currentTicks() -> CPUTicks? {
        var count = mach_msg_type_number_t(0)
        var cpuLoad: processor_info_array_t?
        var cpuCount: natural_t = 0
        let result = host_processor_info(mach_host_self(),
                                         PROCESSOR_CPU_LOAD_INFO,
                                         &cpuCount,
                                         &cpuLoad,
                                         &count)
        guard result == KERN_SUCCESS, let cpuLoad else { return nil }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(UInt(bitPattern: cpuLoad)),
                          vm_size_t(Int(count) * MemoryLayout<integer_t>.size))
        }
        var ticks = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let states = Int(CPU_STATE_MAX)
        for i in 0..<Int(cpuCount) {
            let base = i * states
            ticks.user   += Double(cpuLoad[base + Int(CPU_STATE_USER)])
            ticks.system += Double(cpuLoad[base + Int(CPU_STATE_SYSTEM)])
            ticks.idle   += Double(cpuLoad[base + Int(CPU_STATE_IDLE)])
            ticks.nice   += Double(cpuLoad[base + Int(CPU_STATE_NICE)])
        }
        return ticks
    }
}
```

- [ ] **Step 6: 提交**

```bash
git add Sources/SensorKit/CPUUsage.swift Sources/SensorKit/CPUProvider.swift Tests/SensorKitTests/CPUUsageTests.swift
git commit -m "feat(sensorkit): CPU 占用纯函数 + host_processor_info Provider"
```

---

## Task 3: SensorKit — 内存与 Swap

**Files:**
- Create: `Sources/SensorKit/MemoryProvider.swift`
- Create: `Sources/SensorKit/SwapProvider.swift`
- Create: `Tests/SensorKitTests/SwapStatsTests.swift`

- [ ] **Step 1: 写失败测试（Swap 字节 → GB 换算纯函数）**

Create `Tests/SensorKitTests/SwapStatsTests.swift`:
```swift
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
```

- [ ] **Step 2: 运行确认失败**

Run: `swift test --filter SwapStatsTests`
Expected: `cannot find 'SwapStats' in scope`。

- [ ] **Step 3: 实现 SwapProvider（含纯函数 toGB）**

Create `Sources/SensorKit/SwapProvider.swift`:
```swift
import Foundation
import Darwin

public enum SwapStats {
    /// 字节 → GB（保留 1 位小数）。纯函数，便于测试。
    public static func toGB(bytes: UInt64) -> Double {
        (Double(bytes) / 1_073_741_824.0 * 10).rounded() / 10
    }
}

public struct SwapInfo: Equatable {
    public var usedBytes: UInt64
    public var totalBytes: UInt64
}

/// 薄层：sysctl vm.swapusage。
public struct SwapProvider {
    public init() {}
    public func current() -> SwapInfo? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let r = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        guard r == 0 else { return nil }
        return SwapInfo(usedBytes: usage.xsu_used, totalBytes: usage.xsu_total)
    }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `swift test --filter SwapStatsTests`
Expected: `Executed 2 tests, with 0 failures`。

- [ ] **Step 5: 实现 MemoryProvider（薄层）**

Create `Sources/SensorKit/MemoryProvider.swift`:
```swift
import Foundation
import Darwin

public struct MemoryInfo: Equatable {
    public var usedBytes: UInt64
    public var totalBytes: UInt64
}

/// 薄层：host_statistics64 取页统计 + hw.memsize 取总内存。
public struct MemoryProvider {
    public init() {}

    public func current() -> MemoryInfo? {
        // 总内存
        var total: UInt64 = 0
        var sizeTotal = MemoryLayout<UInt64>.size
        guard sysctlbyname("hw.memsize", &total, &sizeTotal, nil, 0) == 0 else { return nil }

        // 页统计
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(vm_kernel_page_size)
        // “已用”= active + wired + compressed（inactive/free 视为可回收）
        let used = (UInt64(stats.active_count)
                    + UInt64(stats.wire_count)
                    + UInt64(stats.compressor_page_count)) * pageSize
        return MemoryInfo(usedBytes: used, totalBytes: total)
    }
}
```

- [ ] **Step 6: 提交**

```bash
git add Sources/SensorKit/MemoryProvider.swift Sources/SensorKit/SwapProvider.swift Tests/SensorKitTests/SwapStatsTests.swift
git commit -m "feat(sensorkit): 内存 + Swap 采集（含字节换算纯函数）"
```

---

## Task 4: SensorKit — 负载与开机时长

**Files:**
- Create: `Sources/SensorKit/SystemProvider.swift`
- Create: `Tests/SensorKitTests/UptimeTests.swift`

- [ ] **Step 1: 写失败测试（开机时长 → 天数纯函数）**

Create `Tests/SensorKitTests/UptimeTests.swift`:
```swift
import XCTest
@testable import SensorKit

final class UptimeTests: XCTestCase {
    func test21DaysFloor() {
        XCTAssertEqual(Uptime.days(bootEpoch: 1_000_000, nowEpoch: 1_000_000 + 86_400 * 21 + 5), 21)
    }
    func testLessThanADay() {
        XCTAssertEqual(Uptime.days(bootEpoch: 1_000_000, nowEpoch: 1_000_000 + 100), 0)
    }
}
```

- [ ] **Step 2: 运行确认失败**

Run: `swift test --filter UptimeTests`
Expected: `cannot find 'Uptime' in scope`。

- [ ] **Step 3: 实现 SystemProvider（含 Uptime 纯函数）**

Create `Sources/SensorKit/SystemProvider.swift`:
```swift
import Foundation
import Darwin

public enum Uptime {
    /// 由 boot/now 的 epoch 秒算运行天数（向下取整）。纯函数。
    public static func days(bootEpoch: Int, nowEpoch: Int) -> Int {
        max(0, (nowEpoch - bootEpoch) / 86_400)
    }
}

public struct SystemInfo: Equatable {
    public var load1: Double
    public var uptimeDays: Int
}

/// 薄层：getloadavg + sysctl kern.boottime。
public struct SystemProvider {
    public init() {}

    public func current() -> SystemInfo {
        var loads = [Double](repeating: 0, count: 3)
        getloadavg(&loads, 3)

        var bt = timeval()
        var size = MemoryLayout<timeval>.size
        var bootEpoch = 0
        if sysctlbyname("kern.boottime", &bt, &size, nil, 0) == 0 {
            bootEpoch = bt.tv_sec
        }
        let now = Int(Date().timeIntervalSince1970)
        return SystemInfo(load1: (loads[0] * 100).rounded() / 100,
                          uptimeDays: Uptime.days(bootEpoch: bootEpoch, nowEpoch: now))
    }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `swift test --filter UptimeTests`
Expected: `Executed 2 tests, with 0 failures`。

- [ ] **Step 5: 提交**

```bash
git add Sources/SensorKit/SystemProvider.swift Tests/SensorKitTests/UptimeTests.swift
git commit -m "feat(sensorkit): 负载 + 开机时长采集"
```

---

## Task 5: SensorKit — 芯片识别（M1–M5）

**Files:**
- Create: `Sources/SensorKit/ChipModel.swift`
- Create: `Tests/SensorKitTests/ChipModelTests.swift`

- [ ] **Step 1: 写失败测试（brand string → 芯片代次）**

Create `Tests/SensorKitTests/ChipModelTests.swift`:
```swift
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
```

- [ ] **Step 2: 运行确认失败**

Run: `swift test --filter ChipModelTests`
Expected: `cannot find 'ChipModel' in scope`。

- [ ] **Step 3: 实现 ChipModel.parse 纯函数**

Create `Sources/SensorKit/ChipModel.swift`:
```swift
import Foundation

public enum ChipModel: Equatable {
    case m1, m2, m3, m4, m5, unknown

    /// 从 machdep.cpu.brand_string 解析代次。只认 M1–M5；其余 unknown。
    public static func parse(_ brand: String) -> ChipModel {
        let s = brand.lowercased()
        guard s.contains("apple m") else { return .unknown }
        if s.contains("m1") { return .m1 }
        if s.contains("m2") { return .m2 }
        if s.contains("m3") { return .m3 }
        if s.contains("m4") { return .m4 }
        if s.contains("m5") { return .m5 }
        return .unknown
    }

    /// 读取本机 brand string（薄层）。
    public static func current() -> ChipModel {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return .unknown }
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0)
        return parse(String(cString: buf))
    }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `swift test --filter ChipModelTests`
Expected: `Executed 7 tests, with 0 failures`。

- [ ] **Step 5: 提交**

```bash
git add Sources/SensorKit/ChipModel.swift Tests/SensorKitTests/ChipModelTests.swift
git commit -m "feat(sensorkit): 芯片代次识别 M1–M5"
```

---

## Task 6: SensorKit — 温度分类聚合（纯函数，跨芯片核心）

**Files:**
- Create: `Sources/SensorKit/TempClassifier.swift`
- Create: `Tests/SensorKitTests/TempClassifierTests.swift`

- [ ] **Step 1: 写失败测试（传感器名 → CPU/GPU 分类 + 聚合取最大值）**

Create `Tests/SensorKitTests/TempClassifierTests.swift`:
```swift
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
}
```

- [ ] **Step 2: 运行确认失败**

Run: `swift test --filter TempClassifierTests`
Expected: `cannot find 'TempClassifier' in scope`。

- [ ] **Step 3: 实现 TempClassifier 纯函数**

Create `Sources/SensorKit/TempClassifier.swift`:
```swift
import Foundation

public struct Temperatures: Equatable {
    public var cpu: Double?   // nil = 不可用（绝不编造）
    public var gpu: Double?
    public init(cpu: Double?, gpu: Double?) { self.cpu = cpu; self.gpu = gpu }
}

/// 纯函数：按传感器名关键词把读数归类为 CPU / GPU，并取每类最大值。
/// 跨芯片兼容的兜底层：即便各代命名不同，只要含关键词即可命中。
public enum TempClassifier {
    static let cpuKeywords = ["pacc", "eacc", "cpu", "soc"]   // 性能核/能效核/CPU
    static let gpuKeywords = ["gpu"]

    public static func classify(_ sensors: [(String, Double)]) -> Temperatures {
        var cpu: Double? = nil
        var gpu: Double? = nil
        for (name, value) in sensors {
            let n = name.lowercased()
            if gpuKeywords.contains(where: n.contains) {
                gpu = max(gpu ?? -.infinity, value)
            } else if cpuKeywords.contains(where: n.contains) {
                cpu = max(cpu ?? -.infinity, value)
            }
        }
        return Temperatures(cpu: cpu, gpu: gpu)
    }
}
```

> GPU 判定放在 CPU 之前，避免名字里同时含 "soc"/"gpu" 时被误并入 CPU。

- [ ] **Step 4: 运行确认通过**

Run: `swift test --filter TempClassifierTests`
Expected: `Executed 2 tests, with 0 failures`。

- [ ] **Step 5: 提交**

```bash
git add Sources/SensorKit/TempClassifier.swift Tests/SensorKitTests/TempClassifierTests.swift
git commit -m "feat(sensorkit): 温度传感器分类聚合纯函数（跨芯片兜底 + 优雅降级）"
```

---

## Task 7: SensorKit — 温度读取 Provider（IOHIDEventSystemClient）

**Files:**
- Create: `Sources/SensorKit/TempReader.swift`

> 本任务调用私有框架，**无法纯函数单测**，用「运行打印」做集成验证；分类逻辑已在 Task 6 测过。IOKit 框架已在 Package.swift 的 PerfMonApp target 链接；TempReader 用 `dlsym` 运行期取符号，SensorKit 库本身无需额外链接。

- [ ] **Step 1: 实现 TempReader（运行期 dlsym 取私有 IOHID 符号并枚举温度传感器）**

Create `Sources/SensorKit/TempReader.swift`:
```swift
import Foundation
import IOKit

/// 薄层：通过 IOHIDEventSystemClient 枚举温度传感器，返回 (名字, 摄氏度) 列表。
/// 读不到时返回空数组——上层据此优雅降级显示“温度不可用”。
public struct TempReader {
    // kHIDPage_AppleVendor=0xff00；temperature usage=5；temperature event type=15。
    private let kTempUsagePage: Int32 = 0xff00
    private let kTempUsage: Int32 = 0x0005
    private let kIOHIDEventTypeTemperature: Int64 = 15
    private var kTempField: Int64 { 15 << 16 }   // field = (type << 16)

    public init() {}

    public func readAll() -> [(String, Double)] {
        guard let handle = dlopen(nil, RTLD_NOW) else { return [] }
        defer { dlclose(handle) }
        guard
            let pCreate = dlsym(handle, "IOHIDEventSystemClientCreate"),
            let pMatch  = dlsym(handle, "IOHIDEventSystemClientSetMatching"),
            let pCopy   = dlsym(handle, "IOHIDEventSystemClientCopyServices"),
            let pEvent  = dlsym(handle, "IOHIDServiceClientCopyEvent"),
            let pFloat  = dlsym(handle, "IOHIDEventGetFloatValue"),
            let pProp   = dlsym(handle, "IOHIDServiceClientCopyProperty")
        else { return [] }

        typealias CreateFn = @convention(c) (CFAllocator?) -> CFTypeRef?
        typealias MatchFn  = @convention(c) (CFTypeRef?, CFDictionary?) -> Void
        typealias CopyFn   = @convention(c) (CFTypeRef?) -> CFArray?
        typealias EventFn  = @convention(c) (CFTypeRef?, Int64, Int32, Int64) -> CFTypeRef?
        typealias FloatFn  = @convention(c) (CFTypeRef?, Int64) -> Double
        typealias PropFn   = @convention(c) (CFTypeRef?, CFString) -> CFTypeRef?

        let create = unsafeBitCast(pCreate, to: CreateFn.self)
        let setMatching = unsafeBitCast(pMatch, to: MatchFn.self)
        let copyServices = unsafeBitCast(pCopy, to: CopyFn.self)
        let copyEvent = unsafeBitCast(pEvent, to: EventFn.self)
        let getFloat = unsafeBitCast(pFloat, to: FloatFn.self)
        let copyProp = unsafeBitCast(pProp, to: PropFn.self)

        guard let client = create(kCFAllocatorDefault) else { return [] }
        let matching: [String: Any] = [
            "PrimaryUsagePage": kTempUsagePage,
            "PrimaryUsage": kTempUsage,
        ]
        setMatching(client, matching as CFDictionary)
        guard let services = copyServices(client) as? [CFTypeRef] else { return [] }

        var out: [(String, Double)] = []
        for svc in services {
            guard let event = copyEvent(svc, kIOHIDEventTypeTemperature, 0, 0) else { continue }
            let temp = getFloat(event, kTempField)
            let name = (copyProp(svc, "Product" as CFString) as? String) ?? "Sensor"
            if temp > 0 && temp < 130 {   // 合理范围过滤
                out.append((name, (temp * 10).rounded() / 10))
            }
        }
        return out
    }
}
```

- [ ] **Step 2: 写集成验证用例（非断言，打印真实温度）**

Create `Tests/SensorKitTests/TempReaderIntegrationTests.swift`:
```swift
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
        XCTAssertTrue(true)   // 占位：本用例只为观察输出
    }
}
```

- [ ] **Step 3: 运行，观察是否读到合理温度**

Run: `swift test --filter TempReaderIntegrationTests`
Expected: 测试通过；控制台打印若干传感器名与 30–90°C 区间的 CPU/GPU 温度。
> 若读到 0 个传感器：属优雅降级路径，分类显示「不可用」——记录现象（可能需以 root 或调整 matching），不阻塞本计划，UI 会显示「不可用」。

- [ ] **Step 4: 提交**

```bash
git add Sources/SensorKit/TempReader.swift Tests/SensorKitTests/TempReaderIntegrationTests.swift
git commit -m "feat(sensorkit): IOHIDEventSystemClient 温度读取（dlsym 私有符号 + 范围过滤）"
```

---

## Task 8: SensorKit 门面 + Metrics 模型 + 健康分

**Files:**
- Create: `Sources/SensorKit/Metrics.swift`
- Create: `Sources/SensorKit/SensorKit.swift`
- Create: `Tests/SensorKitTests/MetricsTests.swift`

- [ ] **Step 1: 写失败测试（健康分纯函数）**

Create `Tests/SensorKitTests/MetricsTests.swift`:
```swift
import XCTest
@testable import SensorKit

final class MetricsTests: XCTestCase {
    func testHighLoadLowScore() {
        let bad = Metrics(cpuPercent: 82, memPercent: 88, swapPercent: 94,
                          load1: 7.4, uptimeDays: 21,
                          temps: Temperatures(cpu: 78, gpu: 71), topProcesses: [])
        XCTAssertLessThan(Metrics.healthScore(bad), 50)
        XCTAssertTrue((0...100).contains(Metrics.healthScore(bad)))
    }
    func testLowLoadHighScore() {
        let good = Metrics(cpuPercent: 8, memPercent: 40, swapPercent: 0,
                           load1: 1.0, uptimeDays: 1,
                           temps: Temperatures(cpu: 45, gpu: 40), topProcesses: [])
        XCTAssertGreaterThan(Metrics.healthScore(good), 80)
    }
}
```

- [ ] **Step 2: 运行确认失败**

Run: `swift test --filter MetricsTests`
Expected: `cannot find 'Metrics' in scope`。

- [ ] **Step 3: 实现 Metrics 模型 + 健康分纯函数**

Create `Sources/SensorKit/Metrics.swift`:
```swift
import Foundation

public struct ProcessSample: Equatable {
    public var pid: Int
    public var name: String
    public var cpuPercent: Int
    public init(pid: Int, name: String, cpuPercent: Int) {
        self.pid = pid; self.name = name; self.cpuPercent = cpuPercent
    }
}

public struct Metrics: Equatable {
    public var cpuPercent: Int
    public var memPercent: Int
    public var swapPercent: Int
    public var load1: Double
    public var uptimeDays: Int
    public var temps: Temperatures
    public var topProcesses: [ProcessSample]

    public init(cpuPercent: Int, memPercent: Int, swapPercent: Int,
                load1: Double, uptimeDays: Int, temps: Temperatures,
                topProcesses: [ProcessSample]) {
        self.cpuPercent = cpuPercent; self.memPercent = memPercent
        self.swapPercent = swapPercent; self.load1 = load1
        self.uptimeDays = uptimeDays; self.temps = temps
        self.topProcesses = topProcesses
    }

    public static let empty = Metrics(cpuPercent: 0, memPercent: 0, swapPercent: 0,
                                      load1: 0, uptimeDays: 0,
                                      temps: Temperatures(cpu: nil, gpu: nil),
                                      topProcesses: [])

    /// 纯函数：综合健康分 0–100（越高越健康）。
    /// 三项加权扣分：CPU 30%、内存 30%、Swap 40%（Swap 打满对体验影响最大）。
    public static func healthScore(_ m: Metrics) -> Int {
        let penalty = Double(m.cpuPercent) * 0.30
                    + Double(m.memPercent) * 0.30
                    + Double(m.swapPercent) * 0.40
        return max(0, min(100, 100 - Int(penalty.rounded())))
    }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `swift test --filter MetricsTests`
Expected: `Executed 2 tests, with 0 failures`。
> 校验：bad penalty = 82*.3+88*.3+94*.4 = 88.6 → 11 (<50 ✓)；good = 8*.3+40*.3+0 = 14.4 → 86 (>80 ✓)。

- [ ] **Step 5: 实现 SensorKit 门面（汇总一份快照）**

Create `Sources/SensorKit/SensorKit.swift`:
```swift
import Foundation

/// 门面：聚合各 Provider，产出一份 Metrics 快照。
/// CPU 需要两次 tick，故内部保存上一次。
public final class SensorKit {
    private let cpuProvider = CPUProvider()
    private let memProvider = MemoryProvider()
    private let swapProvider = SwapProvider()
    private let sysProvider = SystemProvider()
    private let tempReader = TempReader()
    private var lastTicks: CPUTicks?

    public init() {
        lastTicks = cpuProvider.currentTicks()   // 预热一帧
    }

    public func snapshot() -> Metrics {
        var cpu = 0
        if let cur = cpuProvider.currentTicks() {
            if let prev = lastTicks { cpu = CPUUsage.percent(previous: prev, current: cur) }
            lastTicks = cur
        }
        var memPct = 0
        if let mem = memProvider.current() {
            memPct = Percent.ratio(used: Double(mem.usedBytes), total: Double(mem.totalBytes))
        }
        var swapPct = 0
        if let sw = swapProvider.current() {
            swapPct = Percent.ratio(used: Double(sw.usedBytes), total: Double(sw.totalBytes))
        }
        let sys = sysProvider.current()
        let temps = TempClassifier.classify(tempReader.readAll())

        return Metrics(cpuPercent: cpu, memPercent: memPct, swapPercent: swapPct,
                       load1: sys.load1, uptimeDays: sys.uptimeDays,
                       temps: temps, topProcesses: [])
    }
}
```

- [ ] **Step 6: 提交**

```bash
git add Sources/SensorKit/Metrics.swift Sources/SensorKit/SensorKit.swift Tests/SensorKitTests/MetricsTests.swift
git commit -m "feat(sensorkit): Metrics 模型 + 健康分 + 门面 snapshot()"
```

---

## Task 9: AppState + 采样定时器 + 总览页（毛玻璃 + 温度计样式三）

**Files:**
- Create: `Sources/PerfMonApp/AppState.swift`
- Create: `Sources/PerfMonApp/GlassBackground.swift`
- Create: `Sources/PerfMonApp/RingView.swift`
- Create: `Sources/PerfMonApp/SparklineView.swift`
- Create: `Sources/PerfMonApp/TempGaugeView.swift`
- Create: `Sources/PerfMonApp/OverviewView.swift`
- Modify: `Sources/PerfMonApp/main.swift`

> UI 任务：以「运行可见」为验收标准；纯逻辑已在前序任务覆盖。

- [ ] **Step 1: AppState（每秒采样，发布 Metrics 与历史曲线）**

Create `Sources/PerfMonApp/AppState.swift`:
```swift
import Foundation
import SwiftUI
import Combine
import SensorKit

final class AppState: ObservableObject {
    @Published var metrics: Metrics = .empty
    @Published var cpuHistory: [Double] = []
    @Published var cpuTempHistory: [Double] = []

    private let kit = SensorKit()
    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    private func tick() {
        let m = kit.snapshot()
        metrics = m
        cpuHistory.append(Double(m.cpuPercent))
        if cpuHistory.count > 60 { cpuHistory.removeFirst() }
        if let t = m.temps.cpu {
            cpuTempHistory.append(t)
            if cpuTempHistory.count > 60 { cpuTempHistory.removeFirst() }
        }
    }
}
```

- [ ] **Step 2: GlassBackground（NSVisualEffectView 封装为 SwiftUI 视图）**

Create `Sources/PerfMonApp/GlassBackground.swift`:
```swift
import SwiftUI
import AppKit

struct GlassBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
```

- [ ] **Step 3: RingView（环形仪表）**

Create `Sources/PerfMonApp/RingView.swift`:
```swift
import SwiftUI

struct RingView: View {
    var value: Double
    var label: String
    var unit: String
    var color: Color
    var maxValue: Double = 100

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(1, value / maxValue))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(value))\(unit)").font(.system(size: 18, weight: .bold, design: .monospaced))
                Text(label).font(.system(size: 9)).foregroundColor(.white.opacity(0.55))
            }
        }.frame(width: 84, height: 84)
    }
}
```

- [ ] **Step 4: SparklineView（迷你折线）**

Create `Sources/PerfMonApp/SparklineView.swift`:
```swift
import SwiftUI

struct SparklineView: View {
    var points: [Double]
    var color: Color
    var maxValue: Double = 100

    var body: some View {
        GeometryReader { geo in
            Path { p in
                guard points.count > 1 else { return }
                let stepX = geo.size.width / CGFloat(points.count - 1)
                for (i, v) in points.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = geo.size.height * (1 - CGFloat(min(v, maxValue) / maxValue))
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }.stroke(color, lineWidth: 2)
        }
    }
}
```

- [ ] **Step 5: TempGaugeView（温度计样式三：数字 + 迷你曲线）**

Create `Sources/PerfMonApp/TempGaugeView.swift`:
```swift
import SwiftUI

struct TempGaugeView: View {
    var title: String
    var value: Double?         // nil → 不可用
    var history: [Double]

    private var color: Color {
        guard let v = value else { return .gray }
        if v >= 80 { return Color(red: 1, green: 0.37, blue: 0.31) }
        if v >= 65 { return Color(red: 1, green: 0.83, blue: 0.47) }
        return Color(red: 0.48, green: 0.94, blue: 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🌡 \(title)").font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
            if let v = value {
                Text("\(Int(v))°C").font(.system(size: 26, weight: .bold)).foregroundColor(color)
                SparklineView(points: history, color: color, maxValue: 100).frame(height: 24)
            } else {
                Text("不可用").font(.system(size: 16, weight: .semibold)).foregroundColor(.white.opacity(0.4))
                Text("此芯片暂未适配温度传感器").font(.system(size: 9)).foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .cornerRadius(12)
    }
}
```

- [ ] **Step 6: OverviewView（总览页）**

Create `Sources/PerfMonApp/OverviewView.swift`:
```swift
import SwiftUI
import SensorKit

struct OverviewView: View {
    @ObservedObject var state: AppState

    private var cpuColor: Color {
        let p = state.metrics.cpuPercent
        if p >= 80 { return Color(red: 1, green: 0.37, blue: 0.31) }
        if p >= 50 { return Color(red: 1, green: 0.83, blue: 0.47) }
        return Color(red: 0.48, green: 0.94, blue: 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🚀 PerfMon").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("健康分 \(Metrics.healthScore(state.metrics))")
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
            }
            HStack(spacing: 14) {
                RingView(value: Double(state.metrics.cpuPercent), label: "CPU", unit: "%", color: cpuColor)
                TempGaugeView(title: "CPU 温度", value: state.metrics.temps.cpu, history: state.cpuTempHistory)
                TempGaugeView(title: "GPU 温度", value: state.metrics.temps.gpu, history: [])
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("CPU 负载趋势 · 最近 60s").font(.system(size: 11)).foregroundColor(.white.opacity(0.55))
                SparklineView(points: state.cpuHistory, color: cpuColor).frame(height: 60)
            }.padding(12).background(Color.white.opacity(0.07)).cornerRadius(12)
            HStack(spacing: 20) {
                stat("内存", "\(state.metrics.memPercent)%")
                stat("Swap", "\(state.metrics.swapPercent)%")
                stat("负载", String(format: "%.2f", state.metrics.load1))
                stat("开机", "\(state.metrics.uptimeDays) 天")
            }
        }
        .padding(20)
        .frame(width: 480, height: 360)
    }

    private func stat(_ k: String, _ v: String) -> some View {
        VStack(spacing: 3) {
            Text(k).font(.system(size: 10)).foregroundColor(.white.opacity(0.55))
            Text(v).font(.system(size: 13, weight: .bold, design: .monospaced))
        }
    }
}
```

- [ ] **Step 7: 改 main.swift 接入 AppState + OverviewView**

Replace `Sources/PerfMonApp/main.swift` content:
```swift
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let state = AppState()

    func applicationDidFinishLaunching(_ note: Notification) {
        state.start()
        let root = ZStack {
            GlassBackground()
            OverviewView(state: state)
        }
        let content = NSHostingView(rootView: root)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        content.frame = window.contentView!.bounds
        content.autoresizingMask = [.width, .height]
        window.contentView = content
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
```

- [ ] **Step 8: 构建运行，确认真实数据刷新**

Run: `swift run PerfMonApp`
Expected: 毛玻璃窗口显示 🚀 PerfMon、健康分、CPU 环、CPU/GPU 温度计（数字+曲线，或「不可用」）、CPU 趋势曲线每秒刷新、内存/Swap/负载/开机天数为合理真实值。Ctrl+C 结束。

- [ ] **Step 9: 确认全部测试通过**

Run: `swift test`
Expected: 所有 test target 用例通过（Percent/CPUUsage/SwapStats/Uptime/ChipModel/TempClassifier/Metrics + Temp 集成观察）。

- [ ] **Step 10: 提交**

```bash
git add Sources/PerfMonApp
git commit -m "feat(app): AppState 采样 + 毛玻璃总览页（CPU 环/温度计样式三/趋势曲线）"
```

---

## Self-Review（已检查）

- **Spec 覆盖（本计划范围）：** §2 技术栈（SwiftPM/Xcode 16.2，已实测）✓；§3 毛玻璃 ✓；§5 温度样式三 + M1–M5 分类兜底 + 优雅降级（Task 5/6/7/9）✓；§4.4 总览页 ✓；§8 模块边界（库/可执行/测试 target 分离，纯函数/Provider/门面/UI 分层）✓。
- **本计划不含（后续 Plan）：** 菜单栏图标与面板（§4.1/4.2）、桌面悬浮窗（§4.3）、进程页结束进程（§4.4）、诊断引擎（§7）、一键加速（§6）、历史页。
- **占位符扫描：** 无 TBD/TODO；每个代码步骤含完整代码。
- **类型一致性：** `CPUTicks/CPUUsage/Percent/SwapStats/SwapInfo/MemoryInfo/SystemInfo/Uptime/ChipModel/Temperatures/TempClassifier/Metrics/ProcessSample/SensorKit/AppState` 定义与引用签名一致；`Temperatures` 在 Task 6 定义（含 public init），Task 8/9 引用一致；`Metrics.topProcesses` 类型为 `[ProcessSample]` 全程一致；UI target 中 `import SensorKit` 已加。
- **已知风险：** 温度可能读到 0 个传感器（Task 7 Step 3）→ 走「不可用」降级路径，不阻塞；`IOHIDEventSystemClient` 私有框架不可上架 App Store（仅自用/直接分发）。

## 后续计划（建议顺序，各自独立成 Plan）

- Plan 2：进程页（libproc 采进程 CPU + 结束进程二次确认）。
- Plan 3：诊断引擎（规则 → 问题清单）+ 总览诊断卡。
- Plan 4：一键加速（purge/kill/清缓存/降特效，三步流程 + 日志结果）。
- Plan 5：菜单栏图标 + 弹出面板。
- Plan 6：桌面悬浮窗（NSPanel 置顶可拖动）。
- Plan 7：历史页（数据留存 + 24h 曲线）。
