import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // 单实例:用 NSDistributedNotificationCenter 或自定义文件锁实现。
  // 这里采用简单的 UserDefaults 标记 + 激活已有窗口。
  private static let kSingleInstanceKey = "WildfireChatFlutterDesktopRunning"

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    // 二次点击 Dock 图标时显示窗口
    for window in NSApp.windows {
      if !window.isVisible {
        window.makeKeyAndOrderFront(nil)
      }
      window.deminiaturize(nil)
    }
    return true
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
