# PerfMon Foundation Implementation Plan (Plan 1 of N)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 搭好可构建/可测试的 Swift 工程骨架，实现 SensorKit 核心指标采集（CPU/内存/Swap/负载/开机时长）与跨芯片温度读取，并用毛玻璃「总览」窗口显示真实数据，产出一个能 `make run` 跑起来的可用 App。

**Architecture:** 纯 swiftc + Makefile 构建（本机 SwiftPM 在 Command Line Tools 下不可用，已验证）。核心逻辑拆成纯函数（可单测），系统调用收敛到薄 Provider 层。测试用轻量自定义运行器（`main.swift` 顶层断言 + 退出码），不依赖 XCTest/SwiftPM。UI 用 SwiftUI + AppKit（NSVisualEffectView 毛玻璃）。

**Tech Stack:** Swift 6.0.3、AppKit、SwiftUI、IOKit（`IOHIDEventSystemClient` 私有框架读温度）、mach/host_processor_info、sysctl、Makefile。

**关于本机工具链（已实测）：**
- `swift build` / `swift test`（SwiftPM）❌ 不可用：PackageDescription 链接失败（CLT 缺完整 Xcode）。
- `swiftc` 直接编译 ✓、`import AppKit`/`import IOKit` ✓、自定义测试运行器 ✓、NSVisualEffectView ✓。
- 因此本计划全程用 `swiftc + Makefile`，不使用 SwiftPM。

---

## File Structure

```
CPU_Monitor/
├── Makefile                      # build / test / run / bundle 入口
├── Sources/
│   ├── SensorKit/
│   │   ├── Metrics.swift         # 指标数据模型 (struct)
│   │   ├── Percent.swift         # 纯函数：占比/取整计算
│   │   ├── CPUUsage.swift        # 纯函数：两次 tick 快照 → CPU%
│   │   ├── CPUProvider.swift     # 薄层：host_processor_info 取 tick
│   │   ├── MemoryProvider.swift  # 薄层：host_statistics64 + hw.memsize
│   │   ├── SwapProvider.swift    # 薄层：sysctl vm.swapusage
│   │   ├── SystemProvider.swift  # 薄层：getloadavg / kern.boottime
│   │   ├── ChipModel.swift       # 纯函数：brand string → 芯片代次枚举
│   │   ├── TempClassifier.swift  # 纯函数：传感器名 → CPU/GPU 分类聚合
│   │   ├── TempReader.swift      # 薄层：IOHIDEventSystemClient 枚举温度
│   │   └── SensorKit.swift       # 门面：snapshot() 汇总一份 Metrics
│   └── App/
│       ├── main.swift            # NSApplication 启动入口
│       ├── AppState.swift        # ObservableObject + 采样定时器
│       ├── GlassBackground.swift # NSVisualEffectView 封装 (SwiftUI)
│       ├── TempGaugeView.swift   # 温度计样式三（数字+迷你曲线）
│       ├── RingView.swift        # 环形仪表（CPU 占用）
│       ├── SparklineView.swift   # 迷你折线
│       └── OverviewView.swift    # 总览页
├── Tests/
│   └── main.swift                # 轻量测试运行器（顶层断言）
├── Resources/
│   └── Info.plist                # .app 打包用
└── build/                        # 产物（gitignore）
```

**职责边界：** UI 只读 `AppState`；所有系统调用收敛在 `*Provider` / `TempReader`；纯计算（Percent/CPUUsage/ChipModel/TempClassifier）独立可测。

---

## Task 1: 工程骨架 + Makefile + 测试运行器 + 冒烟窗口

**Files:**
- Create: `Makefile`
- Create: `Sources/SensorKit/Percent.swift`
- Create: `Tests/main.swift`
- Create: `Sources/App/main.swift`
- Create: `Resources/Info.plist`

- [ ] **Step 1: 写第一个失败测试（纯函数 Percent）**

Create `Tests/main.swift`:
```swift
import Foundation

var failures = 0
func expect(_ cond: Bool, _ msg: String) {
    if cond { print("  ✓ \(msg)") }
    else { print("  ✗ FAIL: \(msg)"); failures += 1 }
}
func expectEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String) {
    expect(a == b, "\(msg) (got \(a), want \(b))")
}

print("== Percent ==")
expectEqual(Percent.ratio(used: 21, total: 24), 88, "21/24 → 88")
expectEqual(Percent.ratio(used: 0, total: 0), 0, "0/0 → 0 (no crash)")
expectEqual(Percent.ratio(used: 16, total: 16), 100, "16/16 → 100")

print(failures == 0 ? "\nALL PASS" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
```

- [ ] **Step 2: 写 Makefile（先支持 test 目标）**

Create `Makefile`:
```makefile
SWIFTC := swiftc
SDK := $(shell xcrun --sdk macosx --show-sdk-path)
CORE := $(wildcard Sources/SensorKit/*.swift)
APP := $(wildcard Sources/App/*.swift)
BUILD := build
APP_NAME := PerfMon
BUNDLE := $(BUILD)/$(APP_NAME).app

.PHONY: test build run bundle clean

# 测试：核心源码（排除门面里可能含的 @main）+ 测试运行器，一起编成可执行
test:
	@mkdir -p $(BUILD)
	$(SWIFTC) $(CORE) Tests/main.swift -o $(BUILD)/testrunner
	@$(BUILD)/testrunner

# 编译 App 可执行
build:
	@mkdir -p $(BUILD)
	$(SWIFTC) $(CORE) $(APP) -o $(BUILD)/$(APP_NAME)

run: build
	$(BUILD)/$(APP_NAME)

# 打包成 .app
bundle: build
	@mkdir -p $(BUNDLE)/Contents/MacOS
	@cp $(BUILD)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	@cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	@echo "APPL????" > $(BUNDLE)/Contents/PkgInfo
	@echo "bundled → $(BUNDLE)"

clean:
	rm -rf $(BUILD)
```

- [ ] **Step 3: 运行测试，确认因缺少 Percent 而失败**

Run: `make test`
Expected: 编译报错 `cannot find 'Percent' in scope`（红，符合预期：还没实现）。

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

Run: `make test`
Expected: 三条 `✓` + `ALL PASS`，退出码 0。

- [ ] **Step 6: 写最小 App 入口与 Info.plist（冒烟：一个毛玻璃窗口）**

Create `Resources/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>PerfMon</string>
  <key>CFBundleIdentifier</key><string>vip.maskex.perfmon</string>
  <key>CFBundleVersion</key><string>0.1</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
```

Create `Sources/App/main.swift`:
```swift
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    func applicationDidFinishLaunching(_ note: Notification) {
        let content = NSHostingView(rootView: Text("PerfMon 🚀").font(.title))
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

Run: `make run`
Expected: 弹出一个半透明毛玻璃窗口，居中显示 “PerfMon 🚀”。手动关闭窗口即可退出。

- [ ] **Step 8: 提交**

```bash
git add Makefile Sources Tests Resources
git commit -m "feat: 工程骨架 + Makefile + 测试运行器 + 毛玻璃冒烟窗口"
```

---

## Task 2: SensorKit — CPU 占用（纯函数 + Provider）

**Files:**
- Create: `Sources/SensorKit/CPUUsage.swift`
- Create: `Sources/SensorKit/CPUProvider.swift`
- Modify: `Tests/main.swift`

- [ ] **Step 1: 写失败测试（CPU% 由两次 tick 快照计算）**

Append to `Tests/main.swift` before the final `print(...)`:
```swift
print("== CPUUsage ==")
// CPUTicks: user/system/idle/nice 累计 tick。两次采样差值算占用率。
let t0 = CPUTicks(user: 100, system: 50, idle: 850, nice: 0)   // 总 1000
let t1 = CPUTicks(user: 200, system: 100, idle: 1700, nice: 0) // 总 2050，delta busy=150, idle=850 → 1000
expectEqual(CPUUsage.percent(previous: t0, current: t1), 15, "busy 150 / total 1000 → 15%")
// 无变化 → 0%
expectEqual(CPUUsage.percent(previous: t1, current: t1), 0, "no delta → 0%")
// 退化：total delta 为 0 不崩溃
expectEqual(CPUUsage.percent(previous: t0, current: t0), 0, "same snapshot → 0%")
```

- [ ] **Step 2: 运行测试确认失败**

Run: `make test`
Expected: 编译报错 `cannot find 'CPUTicks' / 'CPUUsage'`。

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

Run: `make test`
Expected: 新增 3 条 `✓`，`ALL PASS`。

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
git add Sources/SensorKit/CPUUsage.swift Sources/SensorKit/CPUProvider.swift Tests/main.swift
git commit -m "feat(sensorkit): CPU 占用纯函数 + host_processor_info Provider"
```

---

## Task 3: SensorKit — 内存与 Swap

**Files:**
- Create: `Sources/SensorKit/MemoryProvider.swift`
- Create: `Sources/SensorKit/SwapProvider.swift`
- Modify: `Tests/main.swift`

- [ ] **Step 1: 写失败测试（内存占比用 Percent，Swap 字节换算）**

Append to `Tests/main.swift` before final print:
```swift
print("== Memory/Swap ==")
// 内存占比复用 Percent（已测）。这里测 Swap 字节 → GB 换算纯函数。
expectEqual(SwapStats.toGB(bytes: 16_106_127_360), 15.0, "≈15GB bytes → 15.0 GB")
expectEqual(SwapStats.toGB(bytes: 0), 0.0, "0 bytes → 0 GB")
```

- [ ] **Step 2: 运行确认失败**

Run: `make test`
Expected: `cannot find 'SwapStats'`。

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

Run: `make test`
Expected: 新增 2 条 `✓`，`ALL PASS`。

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
git add Sources/SensorKit/MemoryProvider.swift Sources/SensorKit/SwapProvider.swift Tests/main.swift
git commit -m "feat(sensorkit): 内存 + Swap 采集（含字节换算纯函数）"
```

---

## Task 4: SensorKit — 负载与开机时长

**Files:**
- Create: `Sources/SensorKit/SystemProvider.swift`
- Modify: `Tests/main.swift`

- [ ] **Step 1: 写失败测试（开机时长 → 天数纯函数）**

Append to `Tests/main.swift` before final print:
```swift
print("== System ==")
// 给定 boot 时间与当前时间，算运行天数（向下取整）。
expectEqual(Uptime.days(bootEpoch: 1_000_000, nowEpoch: 1_000_000 + 86_400 * 21 + 5), 21, "21 天零 5 秒 → 21")
expectEqual(Uptime.days(bootEpoch: 1_000_000, nowEpoch: 1_000_000 + 100), 0, "不到 1 天 → 0")
```

- [ ] **Step 2: 运行确认失败**

Run: `make test`
Expected: `cannot find 'Uptime'`。

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

Run: `make test`
Expected: 新增 2 条 `✓`，`ALL PASS`。

- [ ] **Step 5: 提交**

```bash
git add Sources/SensorKit/SystemProvider.swift Tests/main.swift
git commit -m "feat(sensorkit): 负载 + 开机时长采集"
```

---

## Task 5: SensorKit — 芯片识别（M1–M5）

**Files:**
- Create: `Sources/SensorKit/ChipModel.swift`
- Modify: `Tests/main.swift`

- [ ] **Step 1: 写失败测试（brand string → 芯片代次）**

Append to `Tests/main.swift` before final print:
```swift
print("== ChipModel ==")
expectEqual(ChipModel.parse("Apple M1"), .m1, "Apple M1")
expectEqual(ChipModel.parse("Apple M2 Pro"), .m2, "M2 Pro → m2")
expectEqual(ChipModel.parse("Apple M3"), .m3, "Apple M3")
expectEqual(ChipModel.parse("Apple M4 Max"), .m4, "M4 Max → m4")
expectEqual(ChipModel.parse("Apple M5"), .m5, "Apple M5")
expectEqual(ChipModel.parse("Intel Core i7"), .unknown, "Intel → unknown")
expectEqual(ChipModel.parse("Apple M9"), .unknown, "未知新代 → unknown")
```

- [ ] **Step 2: 运行确认失败**

Run: `make test`
Expected: `cannot find 'ChipModel'`。

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

> 注意 `m1` 子串匹配需放在最前并用精确包含；因 "m1".contains 不会误命中 "m2"，顺序安全。

- [ ] **Step 4: 运行确认通过**

Run: `make test`
Expected: 新增 7 条 `✓`，`ALL PASS`。

- [ ] **Step 5: 提交**

```bash
git add Sources/SensorKit/ChipModel.swift Tests/main.swift
git commit -m "feat(sensorkit): 芯片代次识别 M1–M5"
```

---

## Task 6: SensorKit — 温度分类聚合（纯函数，跨芯片核心）

**Files:**
- Create: `Sources/SensorKit/TempClassifier.swift`
- Modify: `Tests/main.swift`

- [ ] **Step 1: 写失败测试（传感器名 → CPU/GPU 分类 + 聚合取最大值）**

Append to `Tests/main.swift` before final print:
```swift
print("== TempClassifier ==")
let sensors = [
    ("pACC MTR Temp Sensor0", 78.0),   // 性能核 → CPU
    ("eACC MTR Temp Sensor1", 60.0),   // 能效核 → CPU
    ("GPU MTR Temp Sensor2", 71.0),    // GPU
    ("PMU tdev1", 40.0),               // 无关 → 忽略
]
let r = TempClassifier.classify(sensors)
expectEqual(r.cpu, 78.0, "CPU 取性能/能效核最大值 → 78")
expectEqual(r.gpu, 71.0, "GPU → 71")

// 全部无法识别 → nil（优雅降级，不编造）
let r2 = TempClassifier.classify([("Unknown XYZ", 50.0)])
expect(r2.cpu == nil, "无法识别的 CPU 传感器 → nil")
expect(r2.gpu == nil, "无法识别的 GPU 传感器 → nil")
```

- [ ] **Step 2: 运行确认失败**

Run: `make test`
Expected: `cannot find 'TempClassifier'`。

- [ ] **Step 3: 实现 TempClassifier 纯函数**

Create `Sources/SensorKit/TempClassifier.swift`:
```swift
import Foundation

public struct Temperatures: Equatable {
    public var cpu: Double?   // nil = 不可用（绝不编造）
    public var gpu: Double?
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

Run: `make test`
Expected: 新增 4 条 `✓`，`ALL PASS`。

- [ ] **Step 5: 提交**

```bash
git add Sources/SensorKit/TempClassifier.swift Tests/main.swift
git commit -m "feat(sensorkit): 温度传感器分类聚合纯函数（跨芯片兜底 + 优雅降级）"
```

---

## Task 7: SensorKit — 温度读取 Provider（IOHIDEventSystemClient）

**Files:**
- Create: `Sources/SensorKit/TempReader.swift`
- Modify: `Makefile`（链接 IOKit + 私有框架声明）

> 本任务调用私有框架，**无法纯函数单测**，用「运行打印」做集成验证；分类逻辑已在 Task 6 测过。

- [ ] **Step 1: 实现 TempReader（声明私有 IOHID 符号并枚举温度传感器）**

Create `Sources/SensorKit/TempReader.swift`:
```swift
import Foundation
import IOKit

// IOHIDEventSystemClient 私有符号声明（仅链接 IOKit，运行期用 dlsym 取函数，避免编译期缺头文件）。
private typealias HIDClientCreate = @convention(c) (CFAllocator?, CFDictionary?) -> CFTypeRef?
private typealias HIDCopyServices = @convention(c) (CFTypeRef?) -> CFArray?
private typealias HIDCopyEvent    = @convention(c) (CFTypeRef?, Int64, Int32, Int64) -> CFTypeRef?
private typealias HIDGetFloat     = @convention(c) (CFTypeRef?, Int64) -> Double

/// 薄层：通过 IOHIDEventSystemClient 枚举温度传感器，返回 (名字, 摄氏度) 列表。
/// 读不到时返回空数组——上层据此优雅降级显示“温度不可用”。
public struct TempReader {
    // kHIDPage_AppleVendor=0xff00, usage temperature=5; event field temperature
    private let kTempUsagePage: Int32 = 0xff00
    private let kTempUsage: Int32 = 0x0005
    private let kIOHIDEventTypeTemperature: Int64 = 15
    private let kTempField: Int64 = (15 << 16)

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
            let pName   = dlsym(handle, "IOHIDServiceClientCopyProperty")
        else { return [] }

        let create = unsafeBitCast(pCreate, to: (@convention(c) (CFAllocator?) -> CFTypeRef?).self)
        let setMatching = unsafeBitCast(pMatch, to: (@convention(c) (CFTypeRef?, CFDictionary?) -> Void).self)
        let copyServices = unsafeBitCast(pCopy, to: HIDCopyServices.self)
        let copyEvent = unsafeBitCast(pEvent, to: HIDCopyEvent.self)
        let getFloat = unsafeBitCast(pFloat, to: HIDGetFloat.self)
        let copyProp = unsafeBitCast(pName, to: (@convention(c) (CFTypeRef?, CFString) -> CFTypeRef?).self)

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

- [ ] **Step 2: 修改 Makefile 链接 IOKit**

In `Makefile`, change both `$(SWIFTC) ...` lines (in `test` and `build`) to append framework flags. Replace the `test` and `build` recipes:
```makefile
LDFLAGS := -framework IOKit -framework CoreFoundation

test:
	@mkdir -p $(BUILD)
	$(SWIFTC) $(CORE) Tests/main.swift $(LDFLAGS) -o $(BUILD)/testrunner
	@$(BUILD)/testrunner

build:
	@mkdir -p $(BUILD)
	$(SWIFTC) $(CORE) $(APP) $(LDFLAGS) -o $(BUILD)/$(APP_NAME)
```

- [ ] **Step 3: 临时集成验证（在 Tests/main.swift 末尾前打印真实温度）**

Append to `Tests/main.swift` before final print:
```swift
print("== TempReader (集成验证, 非断言) ==")
let raw = TempReader().readAll()
print("  读到 \(raw.count) 个温度传感器")
for (n, v) in raw.prefix(8) { print("    \(n): \(v)°C") }
let cls = TempClassifier.classify(raw)
print("  分类后 → CPU: \(cls.cpu.map{"\($0)°C"} ?? "不可用"), GPU: \(cls.gpu.map{"\($0)°C"} ?? "不可用")")
```

- [ ] **Step 4: 运行，观察是否读到合理温度**

Run: `make test`
Expected: 之前所有断言仍 `ALL PASS`；并打印出若干传感器与 30–90°C 区间的 CPU/GPU 温度。
> 若读到 0 个传感器：属优雅降级路径，分类显示「不可用」——记录现象，后续可调 matching 参数；不阻塞本计划（UI 会显示不可用）。

- [ ] **Step 5: 提交**

```bash
git add Sources/SensorKit/TempReader.swift Makefile Tests/main.swift
git commit -m "feat(sensorkit): IOHIDEventSystemClient 温度读取（dlsym 私有符号 + 范围过滤）"
```

---

## Task 8: SensorKit 门面 + Metrics 模型

**Files:**
- Create: `Sources/SensorKit/Metrics.swift`
- Create: `Sources/SensorKit/SensorKit.swift`
- Modify: `Tests/main.swift`

- [ ] **Step 1: 写失败测试（Metrics 健康分纯函数）**

Append to `Tests/main.swift` before final print:
```swift
print("== Metrics.healthScore ==")
// 占用越高分越低；这里用一个确定的合成样本断言区间。
let bad = Metrics(cpuPercent: 82, memPercent: 88, swapPercent: 94,
                  load1: 7.4, uptimeDays: 21, temps: Temperatures(cpu: 78, gpu: 71),
                  topProcesses: [])
let good = Metrics(cpuPercent: 8, memPercent: 40, swapPercent: 0,
                   load1: 1.0, uptimeDays: 1, temps: Temperatures(cpu: 45, gpu: 40),
                   topProcesses: [])
expect(Metrics.healthScore(bad) < 50, "高负载样本健康分 < 50")
expect(Metrics.healthScore(good) > 80, "低负载样本健康分 > 80")
expect((0...100).contains(Metrics.healthScore(bad)), "分数落在 0–100")
```

- [ ] **Step 2: 运行确认失败**

Run: `make test`
Expected: `cannot find 'Metrics'`。

- [ ] **Step 3: 实现 Metrics 模型 + 健康分纯函数**

Create `Sources/SensorKit/Metrics.swift`:
```swift
import Foundation

public struct ProcessInfo2: Equatable {
    public var pid: Int
    public var name: String
    public var cpuPercent: Int
}

public struct Metrics: Equatable {
    public var cpuPercent: Int
    public var memPercent: Int
    public var swapPercent: Int
    public var load1: Double
    public var uptimeDays: Int
    public var temps: Temperatures
    public var topProcesses: [ProcessInfo2]

    public init(cpuPercent: Int, memPercent: Int, swapPercent: Int,
                load1: Double, uptimeDays: Int, temps: Temperatures,
                topProcesses: [ProcessInfo2]) {
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
    public static func healthScore(_ m: Metrics) -> Int {
        // 三项加权扣分：CPU 30%、内存 30%、Swap 40%（Swap 打满对体验影响最大）。
        let penalty = Double(m.cpuPercent) * 0.30
                    + Double(m.memPercent) * 0.30
                    + Double(m.swapPercent) * 0.40
        return max(0, min(100, 100 - Int(penalty.rounded())))
    }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `make test`
Expected: 新增 3 条 `✓`，`ALL PASS`。
> 校验：bad penalty = 82*.3+88*.3+94*.4 = 24.6+26.4+37.6 = 88.6 → score 11 (<50 ✓)；good = 8*.3+40*.3+0 = 14.4 → score 86 (>80 ✓)。

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
        // CPU
        var cpu = 0
        if let cur = cpuProvider.currentTicks() {
            if let prev = lastTicks { cpu = CPUUsage.percent(previous: prev, current: cur) }
            lastTicks = cur
        }
        // 内存
        var memPct = 0
        if let mem = memProvider.current() {
            memPct = Percent.ratio(used: Double(mem.usedBytes), total: Double(mem.totalBytes))
        }
        // Swap
        var swapPct = 0
        if let sw = swapProvider.current() {
            swapPct = Percent.ratio(used: Double(sw.usedBytes), total: Double(sw.totalBytes))
        }
        // 系统
        let sys = sysProvider.current()
        // 温度
        let temps = TempClassifier.classify(tempReader.readAll())

        return Metrics(cpuPercent: cpu, memPercent: memPct, swapPercent: swapPct,
                       load1: sys.load1, uptimeDays: sys.uptimeDays,
                       temps: temps, topProcesses: [])
    }
}
```

- [ ] **Step 6: 提交**

```bash
git add Sources/SensorKit/Metrics.swift Sources/SensorKit/SensorKit.swift Tests/main.swift
git commit -m "feat(sensorkit): Metrics 模型 + 健康分 + 门面 snapshot()"
```

---

## Task 9: AppState + 采样定时器 + 总览页（毛玻璃 + 温度计样式三）

**Files:**
- Create: `Sources/App/AppState.swift`
- Create: `Sources/App/GlassBackground.swift`
- Create: `Sources/App/RingView.swift`
- Create: `Sources/App/SparklineView.swift`
- Create: `Sources/App/TempGaugeView.swift`
- Create: `Sources/App/OverviewView.swift`
- Modify: `Sources/App/main.swift`

> UI 任务：以「运行可见」为验收标准；纯逻辑已在前序任务覆盖。

- [ ] **Step 1: AppState（每秒采样，发布 Metrics 与历史曲线）**

Create `Sources/App/AppState.swift`:
```swift
import Foundation
import SwiftUI
import Combine

final class AppState: ObservableObject {
    @Published var metrics: Metrics = .empty
    @Published var cpuHistory: [Double] = []      // 最近 60 个采样点
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

Create `Sources/App/GlassBackground.swift`:
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

Create `Sources/App/RingView.swift`:
```swift
import SwiftUI

struct RingView: View {
    var value: Double          // 0–100 或温度
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

Create `Sources/App/SparklineView.swift`:
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

Create `Sources/App/TempGaugeView.swift`:
```swift
import SwiftUI

struct TempGaugeView: View {
    var title: String          // "CPU 温度" / "GPU 温度"
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
        .background(Color.white.opacity(0.07))
        .cornerRadius(12)
    }
}
```

- [ ] **Step 6: OverviewView（总览页）**

Create `Sources/App/OverviewView.swift`:
```swift
import SwiftUI

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

Replace `Sources/App/main.swift` content:
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

Run: `make run`
Expected: 毛玻璃窗口显示 🚀 PerfMon、健康分、CPU 环、CPU/GPU 温度计（数字+曲线，或「不可用」）、CPU 趋势曲线每秒刷新、内存/Swap/负载/开机天数为合理真实值。

- [ ] **Step 9: 打包 .app 验证**

Run: `make bundle && open build/PerfMon.app`
Expected: 双击启动的 .app 行为与 `make run` 一致。

- [ ] **Step 10: 提交**

```bash
git add Sources/App Makefile
git commit -m "feat(app): AppState 采样 + 毛玻璃总览页（CPU 环/温度计样式三/趋势曲线）"
```

---

## Self-Review（已检查）

- **Spec 覆盖（本计划范围）：** §2 技术栈（swiftc 替代，已实测）✓；§3 毛玻璃 ✓；§5 温度样式三 + M1–M5 分类兜底 + 优雅降级（Task 5/6/7/9）✓；§4.4 总览页 ✓；§8 模块边界（纯函数/Provider/门面/UI 分离）✓。
- **本计划不含（后续 Plan）：** 菜单栏图标与面板（§4.1/4.2）、桌面悬浮窗（§4.3）、进程页结束进程（§4.4）、诊断引擎（§7）、一键加速（§6）、历史页（§4.4 历史）。
- **占位符扫描：** 无 TBD/TODO；每个代码步骤含完整代码。
- **类型一致性：** `CPUTicks/CPUUsage/Percent/SwapStats/MemoryInfo/SystemInfo/Uptime/ChipModel/Temperatures/TempClassifier/Metrics/ProcessInfo2/SensorKit/AppState` 在定义与引用处签名一致；`Temperatures` 在 Task 6 定义、Task 8/9 引用一致；`Metrics.healthScore` 签名一致。
- **已知风险：** 温度可能读到 0 个传感器（Task 7 Step 4）→ 走「不可用」降级路径，不阻塞；`IOHIDEventSystemClient` 私有框架不可上架 App Store（仅自用/直接分发）。

## 后续计划（建议顺序，各自独立成 Plan）

- Plan 2：进程页（libproc 采进程 CPU + 结束进程二次确认）。
- Plan 3：诊断引擎（规则 → 问题清单）+ 总览诊断卡。
- Plan 4：一键加速（purge/kill/清缓存/降特效，三步流程 + 日志结果）。
- Plan 5：菜单栏图标 + 弹出面板。
- Plan 6：桌面悬浮窗（NSPanel 置顶可拖动）。
- Plan 7：历史页（数据留存 + 24h 曲线）。
