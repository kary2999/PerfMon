# PerfMon 🚀

macOS 原生性能监控与诊断工具：实时 CPU / 内存 / 温度，菜单栏常驻 + 桌面悬浮窗 + 一键加速 + 智能诊断。毛玻璃风格，Apple Silicon (M1–M5) 适配。

![version](https://img.shields.io/badge/version-1.1-blue) ![platform](https://img.shields.io/badge/macOS-13%2B-lightgrey) ![swift](https://img.shields.io/badge/Swift-6.0-orange)

## 功能

- **总览**：CPU 占用环、CPU/GPU 温度计、负载趋势曲线、健康分
- **进程**：按 CPU 排序的进程排行，一键结束（二次确认，永不结束自身）
- **一键加速**：释放内存(purge) / 结束高占用进程 / 清理缓存 / 降低图形负载
- **诊断**：基于真实「内存压力」的问题清单与处理建议（Swap 仅展示不误报）
- **历史**：CPU/温度曲线 + 记录 CPU 超过 50% 的进程
- **菜单栏图标**：实时 `CPU% · 温度`，过热变红
- **桌面悬浮窗**：置顶、可拖动、可收起成小球，CPU+温度双显

## 技术栈

Swift 6 · SwiftPM · SwiftUI + AppKit（NSVisualEffectView 毛玻璃）· IOKit（`IOHIDEventSystemClient` 读温度）· mach / sysctl。

> ⚠️ 温度读取使用私有框架 `IOHIDEventSystemClient`，**无法上架 Mac App Store**（仅自用 / 直接分发）。M3 实测仅暴露 die 温度，GPU 无专属传感器时如实显示「不可用」。

## 开发

```bash
swift build            # 编译
swift test             # 跑单元测试（SensorKit 纯逻辑）
swift run PerfMonApp   # 运行 App
open Package.swift     # 用 Xcode 打开
```

## 打包分发

```bash
./build-dist.sh          # 读取 AppInfo.version，输出 dist/ 下 .app / .zip / .dmg
./build-dist.sh 2.0      # 临时指定版本号
./tools/make-icon.sh     # 重新生成 App 图标
```

签名为 adhoc（自签）。他人首次打开需「右键 → 打开」放行（未经 Apple 公证）。

## 版本管理

版本号单一来源：[`Sources/PerfMonApp/AppInfo.swift`](Sources/PerfMonApp/AppInfo.swift)。

发布流程：
1. 改 `AppInfo.version`
2. 打 tag：`git tag v1.2 && git push origin v1.2`
3. CI 自动编译、测试、打包并发布 GitHub Release（附 .dmg / .zip）

## 目录结构

```
Sources/SensorKit/    采集与纯逻辑（可单测）：CPU/内存/Swap/温度/诊断/优化
Sources/PerfMonApp/   UI：总览/进程/优化/诊断/历史 + 菜单栏 + 悬浮窗
Tests/SensorKitTests/ XCTest 单元测试
tools/                图标生成
docs/                 设计文档与实现计划
```

## License

MIT
