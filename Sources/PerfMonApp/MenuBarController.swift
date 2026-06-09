import AppKit
import SwiftUI
import Combine
import SensorKit

/// 菜单栏常驻图标：实时显示 CPU% · 温度；点击弹出紧凑面板。
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let state: AppState
    private var cancellable: AnyCancellable?

    init(state: AppState) {
        self.state = state
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // 记住用户用 ⌘-拖动调整后的位置（macOS 无 API 强制置于最右，只能记忆拖动结果）。
        statusItem.autosaveName = "PerfMonStatusItem"
        if let button = statusItem.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
            button.title = "🚀 --"
            button.target = self
            button.action = #selector(togglePopover)
        }
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 240, height: 220)
        popover.contentViewController = NSHostingController(
            rootView: MenuPanelView(state: state))

        // 跟随指标刷新菜单栏标题
        cancellable = state.$metrics.receive(on: RunLoop.main).sink { [weak self] m in
            self?.updateTitle(m)
        }
    }

    private func updateTitle(_ m: Metrics) {
        guard let button = statusItem.button else { return }
        let tempStr = m.temps.cpu.map { "·\(Int($0))°" } ?? ""
        button.title = "🚀 \(m.cpuPercent)%\(tempStr)"
        button.contentTintColor = m.cpuPercent >= 80 ? NSColor.systemRed : nil
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

/// 菜单栏弹出的紧凑面板。
struct MenuPanelView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🚀 PerfMon").font(.system(size: 13, weight: .semibold))
                Spacer()
                if let t = state.metrics.temps.cpu {
                    Text("\(Int(t))°C").font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.byTemp(t))
                }
            }
            bar("CPU", state.metrics.cpuPercent, Theme.byLoad(state.metrics.cpuPercent))
            bar("内存", state.metrics.memPercent, Theme.warm)
            bar("Swap", state.metrics.swapPercent, Theme.byLoad(state.metrics.swapPercent))
            Button {
                _ = state.boost.execute(.purgeMemory)
            } label: {
                Text("⚡ 一键加速").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent)
        }
        .padding(14)
        .frame(width: 240)
    }

    private func bar(_ k: String, _ v: Int, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(k).font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                Text("\(v)%").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(c)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.25))
                    RoundedRectangle(cornerRadius: 3).fill(c)
                        .frame(width: geo.size.width * CGFloat(min(v, 100)) / 100)
                }
            }.frame(height: 5)
        }
    }
}
