import AppKit

/// 截图标注数据模型。所有坐标均为所在覆盖窗视图的逻辑坐标（左下角原点），
/// 最终拍平时由 ScreenCaptureManager 按屏幕缩放系数换算到像素坐标。

/// 带颜色的标注条目（每条标注记录创建时的颜色）。
struct ColoredAnnotation {
    let annotation: Annotation
    let color: NSColor

    func draw(in ctx: NSGraphicsContext) {
        annotation.draw(in: ctx, color: color)
    }
}

enum Annotation {
    /// 矩形框
    case rect(NSRect)
    /// 箭头（起点 → 终点）
    case arrow(from: NSPoint, to: NSPoint)
    /// 画笔（自由折线点集）
    case pen(points: [NSPoint])
    /// 文字（内容 + 左下角位置 + 字号）
    case text(String, at: NSPoint, fontSize: CGFloat)
    /// 马赛克（区域 + 预先渲染好的马赛克图,创建时离线渲染,避免每帧重算）
    case mosaic(rect: NSRect, image: NSImage)

    /// 笔划线宽（统一一档,与 flameshot 默认中号一致）
    static let strokeWidth: CGFloat = 3
    static let textFontSize: CGFloat = 18

    /// 在给定上下文中以指定颜色绘制（逻辑坐标 1:1）。
    func draw(in ctx: NSGraphicsContext, color: NSColor) {
        ctx.saveGraphicsState()
        color.setStroke()
        color.setFill()
        switch self {
        case .rect(let r):
            let path = NSBezierPath(rect: r)
            path.lineWidth = Annotation.strokeWidth
            path.stroke()
        case .arrow(let from, let to):
            let angle = atan2(to.y - from.y, to.x - from.x)
            let barb: CGFloat = 14
            let barbAngle = CGFloat.pi / 7 // 约 25°
            let p1 = NSPoint(x: to.x - barb * cos(angle - barbAngle),
                             y: to.y - barb * sin(angle - barbAngle))
            let p2 = NSPoint(x: to.x - barb * cos(angle + barbAngle),
                             y: to.y - barb * sin(angle + barbAngle))
            let path = NSBezierPath()
            path.move(to: from)
            path.line(to: to)
            path.move(to: p1)
            path.line(to: to)
            path.line(to: p2)
            path.lineWidth = Annotation.strokeWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        case .pen(let points):
            guard points.count > 1 else { break }
            let path = NSBezierPath()
            path.move(to: points[0])
            for p in points.dropFirst() {
                path.line(to: p)
            }
            path.lineWidth = Annotation.strokeWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        case .text(let str, let at, let fontSize):
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: color,
            ]
            str.draw(at: at, withAttributes: attrs)
        case .mosaic(let r, let image):
            image.draw(in: r, from: NSRect(origin: .zero, size: image.size),
                       operation: .sourceOver, fraction: 1)
        }
        ctx.restoreGraphicsState()
    }

    /// 生成马赛克标注：对背景图指定区域做像素化并离屏渲染。
    /// - Parameters:
    ///   - rect: 逻辑坐标区域
    ///   - background: 冻结背景图（整屏,逻辑坐标系与本视图一致）
    static func makeMosaic(rect: NSRect, background: CGImage, scale: CGFloat) -> Annotation? {
        // 逻辑坐标 → 像素坐标（背景图原点在左上,逻辑坐标原点在左下）
        let logicalH = CGFloat(background.height) / scale
        let pixelRect = CGRect(
            x: rect.origin.x * scale,
            y: (logicalH - rect.origin.y - rect.height) * scale,
            width: rect.width * scale,
            height: rect.height * scale
        ).integral
        guard pixelRect.width >= 2, pixelRect.height >= 2 else { return nil }

        let ciImage = CIImage(cgImage: background).cropped(to: pixelRect)
        guard let filter = CIFilter(name: "CIPixellate") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(max(8, min(pixelRect.width, pixelRect.height) / 12),
                        forKey: kCIInputScaleKey)
        guard let output = filter.outputImage else { return nil }

        let context = CIContext()
        guard let cgOut = context.createCGImage(output, from: output.extent) else { return nil }
        let image = NSImage(cgImage: cgOut, size: rect.size)
        return .mosaic(rect: rect, image: image)
    }
}
