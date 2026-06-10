import AppKit
import SwiftUI
import Combine

/// 悬浮窗收起状态（控制器与视图共享）。
final class FloatingWidgetModel: ObservableObject {
    @Published var collapsed = false
}

/// 桌面悬浮窗：可拖动、始终置顶、半透明、可收起成小球。
/// 尺寸已减半；同时显示 CPU 占用与温度。
final class FloatingWidget {
    private let panel: NSPanel
    private let model = FloatingWidgetModel()
    private var cancellable: AnyCancellable?

    // 完整面板减半（原 188 → 96），小球更小（44 → 34）。
    static let fullSize = NSSize(width: 168, height: 104)
    static let ballSize = NSSize(width: 38, height: 38)

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
        panel.appearance = NSAppearance(named: .darkAqua)  // 强制深色，白天也清晰
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let root = FloatingContainer(state: state, model: model)
        let host = NSHostingView(rootView: root)
        host.frame = panel.contentView!.bounds
        host.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(host)

        cancellable = model.$collapsed.receive(on: RunLoop.main).sink { [weak self] collapsed in
            self?.resize(collapsed: collapsed)
        }

        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: f.maxX - 150, y: f.maxY - 30))
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
                   : AnyShape(RoundedRectangle(cornerRadius: 14)))
        .overlay(
            (model.collapsed ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 14)))
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.18), value: model.collapsed)
    }
}

/// 收起后的小球：上 CPU% / 下 温度，双显。点击展开。
struct BallView: View {
    @ObservedObject var state: AppState
    var onExpand: () -> Void

    var body: some View {
        let cpuC = Theme.byLoad(state.metrics.cpuPercent)
        let tempC = state.metrics.temps.cpu.map(Theme.byTemp) ?? .gray
        ZStack {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: min(1, Double(state.metrics.cpuPercent) / 100))
                .stroke(cpuC, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -1) {
                Text("\(state.metrics.cpuPercent)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(cpuC)
                Text(state.metrics.temps.cpu.map { "\(Int($0))°" } ?? "--")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(tempC)
            }.minimumScaleFactor(0.5)
        }
        .padding(3)
        .frame(width: 38, height: 38)
        .contentShape(Circle())
        .onTapGesture { onExpand() }
        .help("CPU \(state.metrics.cpuPercent)% · 温度 \(state.metrics.temps.cpu.map{ "\(Int($0))°C" } ?? "不可用") · 点击展开")
    }
}

/// 完整悬浮面板（紧凑版）：CPU 与 温度并排双显。
struct FloatingWidgetView: View {
    @ObservedObject var state: AppState
    var onCollapse: () -> Void

    var body: some View {
        let cpuC = Theme.byLoad(state.metrics.cpuPercent)
        let tempC = state.metrics.temps.cpu.map(Theme.byTemp) ?? .gray
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                RocketLogo(size: 13)
                Text("PerfMon").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.8))
                Spacer()
                Button(action: onCollapse) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                }.buttonStyle(.plain).help("收起成小球")
            }
            HStack(spacing: 8) {
                metric(icon: "cpu", title: "CPU", value: "\(state.metrics.cpuPercent)%", color: cpuC)
                Divider().frame(height: 28).overlay(Color.white.opacity(0.15))
                metric(icon: "thermometer.medium", title: "温度",
                       value: state.metrics.temps.cpu.map { "\(Int($0))°" } ?? "—", color: tempC)
                Divider().frame(height: 28).overlay(Color.white.opacity(0.15))
                metric(icon: "memorychip", title: "内存",
                       value: "\(state.metrics.memPercent)%", color: Theme.warm)
            }
            // 内存用量（GB）细节
            Text(String(format: "内存 %.1f/%.1f GB · 压力%@",
                        state.metrics.memUsedGB, state.metrics.memTotalGB, state.metrics.pressure.label))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(10)
        .frame(width: 168, height: 104)
    }

    private func metric(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 9)).foregroundColor(.white.opacity(0.5))
                Text(title).font(.system(size: 9)).foregroundColor(.white.opacity(0.55))
            }
            Text(value).font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color).minimumScaleFactor(0.6).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
