import AppKit

/// 截图覆盖窗：无边框、置顶（屏保层级）、可跨 Space 的全屏窗口,
/// 每个显示器一个。内容交互全部在 [CaptureOverlayView]。
final class CaptureOverlayWindow: NSWindow {

    private let overlayView: CaptureOverlayView

    init(screenFrame: NSRect, background: CGImage, scale: CGFloat, manager: ScreenCaptureManager) {
        let view = CaptureOverlayView(
            frame: NSRect(origin: .zero, size: screenFrame.size),
            background: background, scale: scale, manager: manager)
        overlayView = view

        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)

        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .black
        isOpaque = true
        hasShadow = false
        ignoresMouseEvents = false
        // 必须为 false:默认 true 时 close() 会绕过 ARC 直接 release 窗口,
        // 窗口提前 dealloc,而 overlayWindows 数组还持有它,稍后置空数组
        // 再次 release 导致 over-release 崩溃(zombie)。
        isReleasedWhenClosed = false
        contentView = view
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if !overlayView.handleKeyDown(event) {
            super.keyDown(with: event)
        }
    }
}
