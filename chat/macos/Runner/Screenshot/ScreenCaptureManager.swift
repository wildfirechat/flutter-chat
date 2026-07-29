import AppKit
import FlutterMacOS
import ScreenCaptureKit

/// macOS 截图管理器(ScreenCaptureKit 方案,替代 flameshot 子进程)。
///
/// 流程:MethodChannel "chat/screenshot" 的 capture 调用 → 权限检查 →
/// 逐屏截图(排除本 App 窗口)→ 每屏弹一个 [CaptureOverlayWindow] 做
/// 框选与标注 → 确认后拍平为 PNG 写入临时目录并回传路径;取消回传 cancelled。
final class ScreenCaptureManager: NSObject {

    static let shared = ScreenCaptureManager()

    static let channelName = "chat/screenshot"

    private var flutterResult: FlutterResult?
    private var overlayWindows: [CaptureOverlayWindow] = []

    private override init() {
        super.init()
    }

    /// 在 MainFlutterWindow 中注册 MethodChannel。
    func register(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: ScreenCaptureManager.channelName,
                                           binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "capture":
                // excludeSelf:true 时截图排除本 App 全部窗口(“隐藏窗口截图”);
                // false 时本 App 窗口出现在画面里。默认排除。
                let args = call.arguments as? [String: Any]
                let excludeSelf = args?["excludeSelf"] as? Bool ?? true
                self.capture(result: result, excludeSelf: excludeSelf)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - capture 入口

    private func capture(result: @escaping FlutterResult, excludeSelf: Bool) {
        // 只允许一个进行中的截图会话
        guard flutterResult == nil else {
            result(["error": "已有进行中的截图"])
            return
        }

        // 屏幕录制权限:未授权则触发系统弹窗请求;仍无权限则报错,
        // 由 Dart 侧 toast 引导用户到系统设置开启。
        if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
        }
        guard CGPreflightScreenCaptureAccess() else {
            result(["error": "无屏幕录制权限,请在 系统设置→隐私与安全性→屏幕录制 中开启后重试"])
            return
        }

        flutterResult = result
        Task { [weak self] in
            await self?.startCaptureSession(excludeSelf: excludeSelf)
        }
    }

    @MainActor
    private func startCaptureSession(excludeSelf: Bool) async {
        do {
            let content = try await SCShareableContent.current
            let ownBundleId = Bundle.main.bundleIdentifier
            let ownWindows = excludeSelf
                ? content.windows.filter {
                    $0.owningApplication?.bundleIdentifier == ownBundleId
                  }
                : []

            var windows: [CaptureOverlayWindow] = []
            for display in content.displays {
                // excludeSelf 时排除本 App 全部窗口,截图里不出现野火IM自己的界面;
                // 否则不排除,本 App 窗口入镜。
                let filter = excludeSelf
                    ? SCContentFilter(display: display, excludingWindows: ownWindows)
                    : SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                let config = SCStreamConfiguration()
                config.showsCursor = false
                config.width = Int(display.frame.width * CGFloat(filter.pointPixelScale))
                config.height = Int(display.frame.height * CGFloat(filter.pointPixelScale))

                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter, configuration: config)
                let scale = CGFloat(image.width) / display.frame.width

                let window = CaptureOverlayWindow(
                    screenFrame: display.frame,
                    background: image,
                    scale: scale,
                    manager: self)
                windows.append(window)
            }

            guard !windows.isEmpty else {
                finish(result: ["error": "未检测到可用显示器"])
                return
            }

            overlayWindows = windows
            NSApp.activate(ignoringOtherApps: true)
            for w in windows {
                w.makeKeyAndOrderFront(nil)
            }
        } catch {
            finish(result: ["error": "截图失败: \(error.localizedDescription)"])
        }
    }

    // MARK: - 覆盖窗回调

    /// 取消(Esc / 工具条取消按钮)。
    func cancelAll() {
        finish(result: ["cancelled": true])
    }

    /// 确认:裁剪选区 + 拍平标注 → PNG → 回传路径。
    func confirmSelection(selection: NSRect,
                          annotations: [ColoredAnnotation],
                          background: CGImage,
                          scale: CGFloat) {
        guard let flattened = flatten(selection: selection,
                                      annotations: annotations,
                                      background: background,
                                      scale: scale) else {
            finish(result: ["error": "生成截图失败"])
            return
        }
        let path = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("chat_shot_\(Int(Date().timeIntervalSince1970 * 1000)).png")
        guard let data = NSBitmapImageRep(cgImage: flattened)
            .representation(using: .png, properties: [:]) else {
            finish(result: ["error": "生成 PNG 失败"])
            return
        }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            finish(result: ["path": path])
        } catch {
            finish(result: ["error": "写入临时文件失败: \(error.localizedDescription)"])
        }
    }

    /// 复制:拍平结果写入系统剪贴板(PNG + TIFF)。
    func copyToPasteboard(selection: NSRect,
                          annotations: [ColoredAnnotation],
                          background: CGImage,
                          scale: CGFloat) {
        guard let flattened = flatten(selection: selection,
                                      annotations: annotations,
                                      background: background,
                                      scale: scale) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let rep = NSBitmapImageRep(cgImage: flattened)
        if let png = rep.representation(using: .png, properties: [:]) {
            pasteboard.setData(png, forType: .png)
        }
        if let tiff = rep.representation(using: .tiff, properties: [:]) {
            pasteboard.setData(tiff, forType: .tiff)
        }
    }

    // MARK: - 收尾

    private func finish(result: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for w in self.overlayWindows {
                w.close()
            }
            self.overlayWindows = []
            let callback = self.flutterResult
            self.flutterResult = nil
            callback?(result)
        }
    }

    // MARK: - 拍平(裁剪 + 标注)

    /// 把选区从整屏背景中裁出,并把标注按逻辑坐标换算后绘制上去。
    private func flatten(selection: NSRect,
                         annotations: [ColoredAnnotation],
                         background: CGImage,
                         scale: CGFloat) -> CGImage? {
        // 逻辑坐标(左下原点)→ 像素坐标(左上原点)
        let logicalH = CGFloat(background.height) / scale
        let pixelRect = CGRect(
            x: selection.origin.x * scale,
            y: (logicalH - selection.origin.y - selection.height) * scale,
            width: selection.width * scale,
            height: selection.height * scale
        ).integral
        guard pixelRect.width >= 2, pixelRect.height >= 2,
              let cropped = background.cropping(to: pixelRect) else { return nil }

        guard let ctx = CGContext(
            data: nil,
            width: cropped.width,
            height: cropped.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

        ctx.draw(cropped, in: CGRect(x: 0, y: 0,
                                     width: cropped.width, height: cropped.height))

        // 标注:逻辑坐标平移到选区原点,再按缩放系数放大
        ctx.saveGState()
        ctx.translateBy(x: -selection.origin.x, y: -selection.origin.y)
        ctx.scaleBy(x: scale, y: scale)
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        for item in annotations {
            item.draw(in: nsCtx)
        }
        NSGraphicsContext.restoreGraphicsState()
        ctx.restoreGState()

        return ctx.makeImage()
    }
}
