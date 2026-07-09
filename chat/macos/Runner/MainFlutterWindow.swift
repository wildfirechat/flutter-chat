import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // 微信式沉浸标题栏:隐藏系统标题栏,内容延伸到窗口顶部,
    // 红绿灯按钮悬浮在深色侧栏上;顶部边缘仍是原生拖拽区域。
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)

    // window_manager 需要接管窗口,取消默认最小尺寸等限制
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override func layoutIfNeeded() {
    super.layoutIfNeeded()
    
    // 1. 平移红绿灯容器，使其整体向左靠拢，完美容纳在 60px 的侧栏中
    if let titlebarContainer = self.contentView?.superview?.subviews.first(where: { $0.className == "NSTitlebarContainerView" }) {
      var frame = titlebarContainer.frame
      frame.origin.x = -8
      titlebarContainer.frame = frame
    }

    // 2. 缩放红绿灯按钮，使其看起来更小、更精致（微信风格）
    if let closeButton = self.standardWindowButton(.closeButton),
       let minimizeButton = self.standardWindowButton(.miniaturizeButton),
       let zoomButton = self.standardWindowButton(.zoomButton) {
      for button in [closeButton, minimizeButton, zoomButton] {
        button.wantsLayer = true
        button.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.82, y: 0.82))
      }
    }
  }
}
