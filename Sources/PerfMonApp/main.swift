import AppKit
import SwiftUI

extension Notification.Name {
    static let showMainWindow = Notification.Name("PerfMon.showMainWindow")
    static let autoCleanDone = Notification.Name("PerfMon.autoCleanDone")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let state = AppState()
    var menuBar: MenuBarController?
    var floating: FloatingWidget?

    func applicationDidFinishLaunching(_ note: Notification) {
        state.start()

        // 主窗口（毛玻璃 + 标签页）
        let root = ZStack {
            GlassBackground()
            RootView(state: state)
        }
        let content = NSHostingView(rootView: root)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false   // 关闭只是隐藏，便于重新打开
        window.appearance = NSAppearance(named: .darkAqua)  // 强制深色，避免白天对比度过低
        content.frame = window.contentView!.bounds
        content.autoresizingMask = [.width, .height]
        window.contentView = content
        window.center()
        window.makeKeyAndOrderFront(nil)

        // 菜单栏常驻图标
        menuBar = MenuBarController(state: state)

        // 桌面悬浮窗
        floating = FloatingWidget(state: state)
        floating?.show()

        // 菜单栏面板请求"打开主窗口"
        NotificationCenter.default.addObserver(
            self, selector: #selector(showMain), name: .showMainWindow, object: nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showMain() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // 点击 Dock 图标时重新显示主窗口
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMain() }
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// accessory：不出现在 Command+Tab、不占 Dock，仅菜单栏 + 窗口（菜单栏工具惯例）
app.setActivationPolicy(.accessory)
app.run()
