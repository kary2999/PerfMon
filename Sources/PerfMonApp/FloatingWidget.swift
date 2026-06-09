import AppKit
import SwiftUI
import Combine

/// 悬浮窗收起状态（控制器与视图共享）。
final class FloatingWidgetModel: ObservableObject {
    @Published var collapsed = false
}

/// 桌面悬浮窗：可拖动、始终置顶、半透明、可收起成小球。
final class FloatingWidget {
    private let panel: NSPanel
    private let model = FloatingWidgetModel()
    private var cancellable: AnyCancellable?

    static let fullSize = NSSize(width: 188, height: 188)
    static let ballSize = NSSize(width: 44, height: 44)

    init(state: AppState) {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: FloatingWidget.fullSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let root = FloatingContainer(state: state, model: model)
        let host = NSHostingView(rootView: root)
        host.frame = panel.contentView!.bounds
        host.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(host)

        // 收起状态变化 → 调整面板尺寸（保持左上角不动）。
        cancellable = model.$collapsed.receive(on: RunLoop.main).sink { [weak self] collapsed in
            self?.resize(collapsed: collapsed)
        }

        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: f.maxX - 210, y: f.maxY - 30))
        }
    }

    private func resize(collapsed: Bool) {
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        let size = collapsed ? FloatingWidget.ballSize : FloatingWidget.fullSize
        panel.setContentSize(size)
        panel.setFrameTopLeftPoint(topLeft)
    }

    func show() { panel.orderFrontRegardless() }
    func hide() { panel.orderOut(nil) }
}

/// 容器：根据收起状态切换「小球 / 完整面板」与外形（圆 / 圆角矩形）。
struct FloatingContainer: View {
    @ObservedObject var state: AppState
    @ObservedObject var model: FloatingWidgetModel

    var body: some View {
        ZStack {
            GlassBackground(material: .hudWindow)
            if model.collapsed {
                BallView(state: state) { model.collapsed = false }
            } else {
                FloatingWidgetView(state: state) { model.collapsed = true }
            }
        }
        .clipShape(model.collapsed
                   ? AnyShape(Circle())
                   : AnyShape(RoundedRectangle(cornerRadius: 18)))
        .overlay(
            (model.collapsed ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 18)))
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.18), value: model.collapsed)
    }
}

/// 收起后的小球：彩色环 + CPU%，点击展开。
struct BallView: View {
    @ObservedObject var state: AppState
    var onExpand: () -> Void

    var body: some View {
        let c = Theme.byLoad(state.metrics.cpuPercent)
        ZStack {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: min(1, Double(state.metrics.cpuPercent) / 100))
                .stroke(c, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(state.metrics.cpuPercent)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(c)
                .minimumScaleFactor(0.6)
        }
        .padding(4)
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .onTapGesture { onExpand() }
        .help("CPU \(state.metrics.cpuPercent)% · 点击展开")
    }
}

/// 完整悬浮面板（右上角有收起按钮）。
struct FloatingWidgetView: View {
    @ObservedObject var state: AppState
    var onCollapse: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("🚀").font(.system(size: 12))
                Text("PerfMon").font(.system(size: 12, weight: .bold))
                Spacer()
                Button(action: onCollapse) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("收起成小球")
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
