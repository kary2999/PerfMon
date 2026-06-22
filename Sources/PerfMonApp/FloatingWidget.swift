import AppKit
import SwiftUI
import Combine
import SensorKit

/// 悬浮窗收起状态（控制器与视图共享）。
final class FloatingWidgetModel: ObservableObject {
    @Published var collapsed = false
    @Published var hint: String? = nil   // 双击清理时的窗内提示
}

/// 桌面悬浮窗：可拖动、始终置顶、半透明、可收起成小球。
/// 尺寸已减半；同时显示 CPU 占用与温度。
@MainActor
final class FloatingWidget {
    private let panel: NSPanel
    private let model = FloatingWidgetModel()
    private var cancellable: AnyCancellable?

    // 完整面板减半（原 188 → 96），小球更小（44 → 34）。
    static let fullSize = NSSize(width: 168, height: 104)
    static let ballSize = NSSize(width: 38, height: 38)

    private let state: AppState

    init(state: AppState) {
        self.state = state
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

        let root = FloatingContainer(state: state, model: model,
                                     onRelease: { [weak self] in self?.confirmAndRelease() })
        let host = NSHostingView(rootView: root)
        host.frame = panel.contentView!.bounds
        host.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(host)

        cancellable = model.$collapsed.receive(on: RunLoop.main).sink { [weak self] collapsed in
            self?.resize(collapsed: collapsed)
        }

        // 自动清理完成 → 窗内闪一条提示
        NotificationCenter.default.addObserver(forName: .autoCleanDone, object: nil, queue: .main) { [model] _ in
            model.hint = "✓ 自动清理"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if model.hint == "✓ 自动清理" { model.hint = nil }
            }
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

    private var releaseWindow: NSWindow?

    /// 双击悬浮窗触发：打开「选择性释放内存」面板——列出可关闭的第三方应用，用户勾选后释放。
    func confirmAndRelease() {
        if let w = releaseWindow {
            w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return
        }
        let root = ZStack {
            GlassBackground()
            ReleaseMemoryView(state: state, onClose: { [weak self] in
                self?.releaseWindow?.close(); self?.releaseWindow = nil
            })
        }
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 440),
                           styleMask: [.titled, .closable, .fullSizeContentView],
                           backing: .buffered, defer: false)
        win.title = "释放内存"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.appearance = NSAppearance(named: .darkAqua)
        win.contentView = NSHostingView(rootView: root)
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        releaseWindow = win
    }
}

struct FloatingContainer: View {
    @ObservedObject var state: AppState
    @ObservedObject var model: FloatingWidgetModel
    var onRelease: () -> Void

    private var radius: CGFloat { model.collapsed ? 19 : 14 }   // 38/2=19 → 圆

    var body: some View {
        ZStack {
            GlassBackground(material: .hudWindow, cornerRadius: radius)  // 毛玻璃层自带圆角，根治黑方块
            if model.collapsed {
                BallView(state: state, onExpand: { model.collapsed = false }, onRelease: onRelease)
            } else {
                FloatingWidgetView(state: state, onCollapse: { model.collapsed = true }, onRelease: onRelease)
            }
            // 清理提示：保持在窗内，按状态用不同的清爽样式
            if let h = model.hint { hintOverlay(h) }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.white.opacity(0.18), lineWidth: 1))
        .animation(.easeInOut(duration: 0.18), value: model.collapsed)
        .animation(.easeInOut(duration: 0.18), value: model.hint)
    }

    /// 窗内清理提示：收起态=中心图标，展开态=底部色条。均裁剪在窗内，无独立弹窗/方块。
    @ViewBuilder
    private func hintOverlay(_ h: String) -> some View {
        let done = h.hasPrefix("✓")
        if model.collapsed {
            ZStack {
                Circle().fill(Color.black.opacity(0.5))
                Image(systemName: done ? "checkmark" : "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(done ? Theme.good : .white)
            }
        } else {
            VStack {
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: done ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .bold))
                    Text(done ? "已释放缓存" : "正在清理…").font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background((done ? Theme.good : Theme.cool).opacity(0.9))
            }
        }
    }
}

/// 收起后的小球：上 CPU% / 下 温度，双显。点击展开。
struct BallView: View {
    @ObservedObject var state: AppState
    var onExpand: () -> Void
    var onRelease: () -> Void

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
        .onTapGesture(count: 2) { onRelease() }
        .onTapGesture { onExpand() }
        .help("单击展开 · 双击释放内存")
    }
}

/// 完整悬浮面板（紧凑版）：CPU 与 温度并排双显。
struct FloatingWidgetView: View {
    @ObservedObject var state: AppState
    var onCollapse: () -> Void
    var onRelease: () -> Void

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
            Text(String(format: "内存 %.1f/%.1f GB · 双击选择性释放",
                        state.metrics.memUsedGB, state.metrics.memTotalGB))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(10)
        .frame(width: 168, height: 104)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onRelease() }
        .help("双击清理缓存释放空间（不关闭任何应用）")
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
