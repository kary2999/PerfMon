import AppKit
import SwiftUI

/// 桌面悬浮窗：可拖动、始终置顶、半透明。
final class FloatingWidget {
    private let panel: NSPanel

    init(state: AppState) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 188, height: 188),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let root = ZStack {
            GlassBackground(material: .hudWindow)
            FloatingWidgetView(state: state)
        }.clipShape(RoundedRectangle(cornerRadius: 18))
        let host = NSHostingView(rootView: root)
        host.frame = panel.contentView!.bounds
        host.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(host)

        // 默认放右上角
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: f.maxX - 210, y: f.maxY - 30))
        }
    }

    func show() { panel.orderFrontRegardless() }
    func hide() { panel.orderOut(nil) }
}

struct FloatingWidgetView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("🚀").font(.system(size: 12))
                Text("PerfMon").font(.system(size: 12, weight: .bold))
                Spacer()
                Text("置顶").font(.system(size: 9)).foregroundColor(.white.opacity(0.4))
            }
            RingView(value: Double(state.metrics.cpuPercent), label: "CPU %",
                     unit: "", color: Theme.byLoad(state.metrics.cpuPercent))
            VStack(spacing: 4) {
                row("🌡 CPU 温", state.metrics.temps.cpu.map { "\(Int($0))°C" } ?? "不可用",
                    state.metrics.temps.cpu.map(Theme.byTemp) ?? .gray)
                row("内存", "\(state.metrics.memPercent)%", Theme.warm)
                row("Swap", "\(state.metrics.swapPercent)%", Theme.byLoad(state.metrics.swapPercent))
            }
        }
        .padding(13)
        .frame(width: 188, height: 188)
    }

    private func row(_ k: String, _ v: String, _ c: Color) -> some View {
        HStack {
            Text(k).font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(v).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(c)
        }
    }
}
