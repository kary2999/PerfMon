import AppKit
import SwiftUI

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
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 408),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
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

        NSApp.activate(ignoringOtherApps: true)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
