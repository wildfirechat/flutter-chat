import AppKit

/// 截图覆盖窗的内容视图：冻结背景 + 变暗遮罩 + 框选 + 标注编辑 + 工具条。
///
/// 交互模型（对齐 flameshot gui）:
/// - 空闲:拖拽创建选区;
/// - 已有选区:选区内拖动=移动,8 个手柄=调整大小,选区外拖拽=重新框选;
/// - 标注工具激活时,在选区内拖拽绘制(文字为点击);
/// - Esc 取消,Enter/双击确认,⌘Z/⇧⌘Z 撤销重做。
final class CaptureOverlayView: NSView {

    enum Tool: Int {
        case select = 0, rect, arrow, pen, text, mosaic
    }

    private enum DragMode {
        case none, create, move, resize(Int), annotate
    }

    // MARK: - 状态

    private let background: CGImage
    private let backgroundImage: NSImage
    private let scale: CGFloat

    private(set) var selection: NSRect?
    private var dragStart: NSPoint = .zero
    private var dragMode: DragMode = .none
    private var selectionAtDragStart: NSRect = .null

    private(set) var annotations: [ColoredAnnotation] = []
    private var redoStack: [ColoredAnnotation] = []
    private var inProgress: Annotation?

    private(set) var activeTool: Tool = .select
    private(set) var activeColor: NSColor = .systemRed

    private weak var manager: ScreenCaptureManager?

    private var toolbar: NSStackView?
    private var paletteView: NSStackView?
    private var textField: NSTextField?

    /// 工具条按钮引用,用于切换激活态高亮(flameshot 风格:激活项蓝色)
    private var toolButtons: [NSButton] = []
    private var swatchButtons: [NSButton] = []

    private static let handleSize: CGFloat = 10
    private static let palette: [NSColor] = [
        .systemRed, .systemYellow, .systemGreen, .systemBlue, .white, .black,
    ]

    // MARK: - 初始化

    init(frame frameRect: NSRect, background: CGImage, scale: CGFloat, manager: ScreenCaptureManager) {
        self.background = background
        self.backgroundImage = NSImage(cgImage: background, size: frameRect.size)
        self.scale = scale
        self.manager = manager
        super.init(frame: frameRect)

        let tracking = NSTrackingArea(rect: bounds,
                                      options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
                                      owner: self, userInfo: nil)
        addTrackingArea(tracking)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    /// flameshot 风格配色:蓝色选区/手柄 + 白色工具栏深色图标
    private static let selectionBlue = NSColor(calibratedRed: 0.20, green: 0.50, blue: 0.95, alpha: 1)
    private static let toolbarBackground = NSColor.white.withAlphaComponent(0.96)
    private static let toolbarIcon = NSColor(calibratedWhite: 0.2, alpha: 1)

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        backgroundImage.draw(in: bounds)

        // 选区外变暗
        if let sel = selection {
            let path = NSBezierPath(rect: bounds)
            path.append(NSBezierPath(rect: sel))
            path.windingRule = .evenOdd
            NSColor.black.withAlphaComponent(0.5).setFill()
            path.fill()
        } else {
            NSColor.black.withAlphaComponent(0.5).setFill()
            NSBezierPath(rect: bounds).fill()
        }

        // 已提交标注
        if let ctx = NSGraphicsContext.current {
            for item in annotations {
                item.draw(in: ctx)
            }
            if let ip = inProgress {
                ip.draw(in: ctx, color: activeColor)
            }
        }

        // 选区边框与手柄(flameshot 风格:蓝色边框 + 蓝色圆点手柄)
        if let sel = selection {
            CaptureOverlayView.selectionBlue.setStroke()
            let border = NSBezierPath(rect: sel)
            border.lineWidth = 2
            border.stroke()

            for (_, r) in handleRects() {
                let dot = NSBezierPath(ovalIn: r)
                CaptureOverlayView.selectionBlue.setFill()
                dot.fill()
                NSColor.white.setStroke()
                dot.lineWidth = 1.5
                dot.stroke()
            }
        }
    }

    // MARK: - 手柄

    /// 8 个手柄:0-3 四角(左下/右下/左上/右上),4-7 四边中点(下/右/上/左)。
    private func handleRects() -> [(Int, NSRect)] {
        guard let sel = selection else { return [] }
        let h = CaptureOverlayView.handleSize
        func r(_ x: CGFloat, _ y: CGFloat) -> NSRect {
            NSRect(x: x - h / 2, y: y - h / 2, width: h, height: h)
        }
        return [
            (0, r(sel.minX, sel.minY)), (1, r(sel.maxX, sel.minY)),
            (2, r(sel.minX, sel.maxY)), (3, r(sel.maxX, sel.maxY)),
            (4, r(sel.midX, sel.minY)), (5, r(sel.maxX, sel.midY)),
            (6, r(sel.midX, sel.maxY)), (7, r(sel.minX, sel.midY)),
        ]
    }

    private func hitHandle(at point: NSPoint) -> Int? {
        for (idx, r) in handleRects() where r.insetBy(dx: -3, dy: -3).contains(point) {
            return idx
        }
        return nil
    }

    // MARK: - 鼠标

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // 双击确认(macOS NSView 没有 mouseDoubleClick,用 clickCount 判断)
        if event.clickCount == 2, selection != nil, selection!.contains(point) {
            confirm()
            return
        }

        if activeTool == .text, let sel = selection, sel.contains(point) {
            beginTextInput(at: point)
            return
        }

        if let sel = selection {
            if let handle = hitHandle(at: point) {
                dragMode = .resize(handle)
                selectionAtDragStart = sel
                dragStart = point
                return
            }
            if sel.contains(point) {
                if activeTool == .select {
                    dragMode = .move
                } else {
                    dragMode = .annotate
                    beginAnnotation(at: point)
                }
                selectionAtDragStart = sel
                dragStart = point
                return
            }
        }

        // 选区外:重新框选
        dragMode = .create
        dragStart = point
        selection = nil
        annotations.removeAll()
        redoStack.removeAll()
        inProgress = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        // 拖动(框选/移动/调整/标注)期间隐藏工具条,松手后再显示
        toolbar?.isHidden = true
        paletteView?.isHidden = true
        switch dragMode {
        case .none:
            break
        case .create:
            selection = rectFrom(dragStart, point)
            updateToolbar()
        case .move:
            var sel = selectionAtDragStart
            sel.origin.x += point.x - dragStart.x
            sel.origin.y += point.y - dragStart.y
            selection = clampToBounds(sel)
            updateToolbar()
        case .resize(let handle):
            selection = resizeRect(handle: handle, to: point)
            updateToolbar()
        case .annotate:
            updateAnnotation(to: point)
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        defer {
            dragMode = .none
            // 拖动结束,恢复工具条显示(颜色条显隐由 updatePaletteBar 决定)
            toolbar?.isHidden = false
            updatePaletteBar()
            needsDisplay = true
        }

        switch dragMode {
        case .create:
            if var sel = selection {
                // 误触(几乎没拖出区域)视为取消本次框选
                if sel.width < 4 || sel.height < 4 {
                    selection = nil
                } else {
                    sel = clampToBounds(sel)
                    selection = sel
                }
            }
            updateToolbar()
        case .move, .resize:
            updateToolbar()
        case .annotate:
            commitInProgress()
            updateToolbar()
        case .none:
            break
        }
        _ = point
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseEntered(with event: NSEvent) {
        updateCursor(with: event)
    }

    /// 光标规则:选区内十字(便于移动/标注),选区外用系统默认箭头。
    private func updateCursor(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let sel = selection, sel.contains(point) {
            NSCursor.crosshair.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    // MARK: - 键盘(由窗口转发)

    func handleKeyDown(_ event: NSEvent) -> Bool {
        // Esc:优先关闭文字输入,其次取消整个截图
        if event.keyCode == 53 {
            if textField != nil {
                cancelTextInput()
            } else {
                manager?.cancelAll()
            }
            return true
        }
        // Enter:确认
        if event.keyCode == 36 {
            if textField != nil {
                commitTextInput()
            } else if selection != nil {
                confirm()
            }
            return true
        }
        // ⌘Z / ⇧⌘Z
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "z" {
            if event.modifierFlags.contains(.shift) {
                redo()
            } else {
                undo()
            }
            return true
        }
        return false
    }

    // MARK: - 标注

    private func beginAnnotation(at point: NSPoint) {
        switch activeTool {
        case .rect:
            inProgress = .rect(NSRect(origin: point, size: .zero))
        case .arrow:
            inProgress = .arrow(from: point, to: point)
        case .pen:
            inProgress = .pen(points: [point])
        case .mosaic:
            inProgress = .rect(NSRect(origin: point, size: .zero))
        case .text, .select:
            break
        }
    }

    private func updateAnnotation(to point: NSPoint) {
        guard let ip = inProgress else { return }
        switch ip {
        case .rect:
            // 锚点必须固定为鼠标按下点(dragStart),不能用上一步归一化后的
            // r.origin——反向拖动(从下往上/从右往左)时锚点会跟随鼠标,
            // 矩形塌缩成一条线
            inProgress = .rect(rectFrom(dragStart, point))
        case .arrow(let from, _):
            inProgress = .arrow(from: from, to: point)
        case .pen(var points):
            points.append(point)
            inProgress = .pen(points: points)
        case .text, .mosaic:
            // mosaic 的进行中形态就是 rect
            if case .rect = ip {
                inProgress = .rect(rectFrom(dragStart, point))
            }
        }
    }

    private func commitInProgress() {
        guard let ip = inProgress else { return }
        inProgress = nil

        var final: Annotation? = ip
        // 马赛克需要把临时 rect 转换为马赛克标注
        if activeTool == .mosaic, case .rect(let r) = ip {
            guard r.width >= 4, r.height >= 4 else { return }
            final = Annotation.makeMosaic(rect: r, background: background, scale: scale)
        }
        // 过小的矩形/箭头视为误触
        if case .rect(let r) = ip, activeTool == .rect, r.width < 4 || r.height < 4 {
            final = nil
        }
        if case .pen(let pts) = ip, pts.count < 2 {
            final = nil
        }

        if let f = final {
            annotations.append(ColoredAnnotation(annotation: f, color: activeColor))
            redoStack.removeAll()
        }
    }

    // MARK: - 文字输入

    private func beginTextInput(at point: NSPoint) {
        cancelTextInput()
        let field = NSTextField(frame: NSRect(x: point.x, y: point.y - 6, width: 220, height: 28))
        field.font = NSFont.boldSystemFont(ofSize: Annotation.textFontSize)
        field.textColor = activeColor
        field.isBezeled = true
        field.bezelStyle = .squareBezel
        field.target = self
        field.action = #selector(textInputCommitted(_:))
        addSubview(field)
        textField = field
        window?.makeFirstResponder(field)
    }

    @objc private func textInputCommitted(_ sender: NSTextField) {
        commitTextInput()
    }

    private func commitTextInput() {
        guard let field = textField else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            annotations.append(ColoredAnnotation(
                annotation: .text(text, at: field.frame.origin, fontSize: Annotation.textFontSize),
                color: activeColor))
            redoStack.removeAll()
        }
        cancelTextInput()
        window?.makeFirstResponder(self)
    }

    private func cancelTextInput() {
        textField?.removeFromSuperview()
        textField = nil
        needsDisplay = true
    }

    // MARK: - 撤销/重做

    func undo() {
        guard let last = annotations.popLast() else { return }
        redoStack.append(last)
        needsDisplay = true
    }

    func redo() {
        guard let item = redoStack.popLast() else { return }
        annotations.append(item)
        needsDisplay = true
    }

    // MARK: - 工具条

    /// 工具条图标统一尺寸(默认 SF Symbols 太小,放大到 20pt)
    private func symbolImage(_ name: String, _ tip: String) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        return NSImage(systemSymbolName: name, accessibilityDescription: tip)!
            .withSymbolConfiguration(config)!
    }

    /// 马赛克工具图标:自绘 3×3 棋盘格(SF Symbols 没有贴切的像素化图标)。
    /// template 模式,颜色跟随按钮 contentTintColor(未激活深灰/激活蓝色)。
    private func mosaicSymbolImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            let cell = rect.width / 3
            for row in 0..<3 {
                for col in 0..<3 where (row + col) % 2 == 0 {
                    NSRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell,
                           width: cell, height: cell).fill()
                }
            }
            let border = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
            border.lineWidth = 1
            border.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    private func makeToolbar() -> NSStackView {
        toolButtons = []
        swatchButtons = []

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10

        let tools: [(Tool, String, String)] = [
            (.select, "cursorarrow.rays", "框选/移动"),
            (.rect, "square", "矩形"),
            (.arrow, "arrow.up.right", "箭头"),
            (.pen, "pencil", "画笔"),
            (.text, "textformat", "文字"),
            (.mosaic, "square.grid.3x3", "马赛克"),
        ]
        for (tool, symbol, tip) in tools {
            // 马赛克用自绘棋盘格图标,其余用 SF Symbols
            let image = tool == .mosaic ? mosaicSymbolImage() : symbolImage(symbol, tip)
            let button = NSButton(
                image: image,
                target: self, action: #selector(toolTapped(_:)))
            button.tag = tool.rawValue
            button.toolTip = tip
            button.isBordered = false
            button.contentTintColor = CaptureOverlayView.toolbarIcon
            toolButtons.append(button)
            stack.addArrangedSubview(button)
        }

        stack.addArrangedSubview(separator())

        let actions: [(String, Selector, String)] = [
            ("arrow.uturn.left", #selector(undoTapped), "撤销"),
            ("arrow.uturn.right", #selector(redoTapped), "重做"),
            ("doc.on.doc", #selector(copyTapped), "复制"),
            ("checkmark", #selector(saveTapped), "保存"),
            ("xmark", #selector(cancelTapped), "取消"),
        ]
        for (symbol, action, tip) in actions {
            let button = NSButton(
                image: symbolImage(symbol, tip),
                target: self, action: action)
            button.toolTip = tip
            button.isBordered = false
            button.contentTintColor = CaptureOverlayView.toolbarIcon
            stack.addArrangedSubview(button)
        }

        stack.wantsLayer = true
        stack.layer?.backgroundColor = CaptureOverlayView.toolbarBackground.cgColor
        stack.layer?.cornerRadius = 8
        stack.layer?.borderWidth = 0.5
        stack.layer?.borderColor = NSColor.gray.withAlphaComponent(0.4).cgColor
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)

        refreshToolbarHighlights()
        return stack
    }

    private func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.setContentHuggingPriority(.required, for: .horizontal)
        return box
    }

    /// 颜色选择条(对齐微信):选中标注工具时显示在主工具条下方。
    private func makePaletteBar() -> NSStackView {
        swatchButtons = []
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10

        for color in CaptureOverlayView.palette {
            let swatch = NSButton(frame: NSRect(x: 0, y: 0, width: 22, height: 22))
            swatch.title = ""
            swatch.isBordered = false
            swatch.wantsLayer = true
            swatch.layer?.backgroundColor = color.cgColor
            swatch.layer?.cornerRadius = 4
            // NSButton 无标题无图像时固有尺寸会塌缩(在 stack 里显示为空白),
            // 必须显式约束宽高
            swatch.translatesAutoresizingMaskIntoConstraints = false
            swatch.widthAnchor.constraint(equalToConstant: 22).isActive = true
            swatch.heightAnchor.constraint(equalToConstant: 22).isActive = true
            swatch.layer?.borderWidth = 1
            swatch.layer?.borderColor = NSColor.gray.cgColor
            swatch.target = self
            swatch.action = #selector(colorTapped(_:))
            swatch.tag = CaptureOverlayView.palette.firstIndex(of: color) ?? 0
            swatch.toolTip = "颜色"
            swatchButtons.append(swatch)
            stack.addArrangedSubview(swatch)
        }

        stack.wantsLayer = true
        stack.layer?.backgroundColor = CaptureOverlayView.toolbarBackground.cgColor
        stack.layer?.cornerRadius = 8
        stack.layer?.borderWidth = 0.5
        stack.layer?.borderColor = NSColor.gray.withAlphaComponent(0.4).cgColor
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        refreshToolbarHighlights()
        return stack
    }

    /// 颜色条只在「有颜色的标注工具」(矩形/箭头/画笔/文字)激活时显示。
    private var paletteBarVisible: Bool {
        switch activeTool {
        case .rect, .arrow, .pen, .text:
            return true
        case .select, .mosaic:
            return false
        }
    }

    private func updatePaletteBar() {
        guard paletteBarVisible, let bar = toolbar, bar.superview != nil else {
            paletteView?.removeFromSuperview()
            paletteView = nil
            return
        }
        if paletteView == nil {
            let palette = makePaletteBar()
            addSubview(palette)
            paletteView = palette
        }
        paletteView?.layoutSubtreeIfNeeded()
        let size = paletteView?.fittingSize ?? .zero
        // 颜色条跟在主工具条下方,左对齐
        let origin = NSPoint(x: bar.frame.minX, y: bar.frame.minY - size.height - 4)
        paletteView?.frame = NSRect(origin: origin, size: size)
        paletteView?.isHidden = toolbar?.isHidden ?? false
    }

    private func updateToolbar() {
        guard let sel = selection, sel.width >= 4, sel.height >= 4 else {
            toolbar?.removeFromSuperview()
            toolbar = nil
            updatePaletteBar()
            return
        }
        if toolbar == nil {
            let bar = makeToolbar()
            addSubview(bar)
            toolbar = bar
        }
        toolbar?.layoutSubtreeIfNeeded()
        let size = toolbar?.fittingSize ?? .zero
        // 优先放在选区下缘外侧,不够高时翻到选区内上缘
        var origin = NSPoint(x: sel.maxX - size.width, y: sel.minY - size.height - 8)
        if origin.y < 4 {
            origin.y = sel.maxY + 8 <= bounds.height - size.height - 4
                ? sel.maxY + 8
                : sel.maxY - size.height - 8
        }
        origin.x = max(4, min(origin.x, bounds.width - size.width - 4))
        toolbar?.frame = NSRect(origin: origin, size: size)
        updatePaletteBar()
    }

    // MARK: - 工具条动作

    /// 激活态高亮(flameshot 风格):当前工具蓝色,当前颜色色板加蓝色描边。
    private func refreshToolbarHighlights() {
        for button in toolButtons {
            let active = button.tag == activeTool.rawValue
            button.contentTintColor = active
                ? CaptureOverlayView.selectionBlue
                : CaptureOverlayView.toolbarIcon
        }
        for swatch in swatchButtons {
            let active = CaptureOverlayView.palette[swatch.tag] == activeColor
            swatch.layer?.borderWidth = active ? 2 : 1
            swatch.layer?.borderColor = active
                ? CaptureOverlayView.selectionBlue.cgColor
                : NSColor.gray.cgColor
        }
    }

    @objc private func toolTapped(_ sender: NSButton) {
        activeTool = Tool(rawValue: sender.tag) ?? .select
        refreshToolbarHighlights()
        // 切换工具时同步颜色条显隐(对齐微信:标注工具激活才显示颜色条)
        updatePaletteBar()
    }

    @objc private func colorTapped(_ sender: NSButton) {
        activeColor = CaptureOverlayView.palette[sender.tag]
        refreshToolbarHighlights()
    }

    @objc private func undoTapped() { undo() }
    @objc private func redoTapped() { redo() }

    @objc private func copyTapped() {
        guard let sel = selection else { return }
        commitTextInput()
        manager?.copyToPasteboard(selection: sel,
                                  annotations: annotations,
                                  background: background,
                                  scale: scale)
    }

    @objc private func saveTapped() {
        confirm()
    }

    @objc private func cancelTapped() {
        manager?.cancelAll()
    }

    private func confirm() {
        guard let sel = selection else { return }
        commitTextInput()
        manager?.confirmSelection(selection: sel,
                                  annotations: annotations,
                                  background: background,
                                  scale: scale)
    }

    // MARK: - 几何

    private func rectFrom(_ a: NSPoint, _ b: NSPoint) -> NSRect {
        NSRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    private func clampToBounds(_ r: NSRect) -> NSRect {
        var out = r
        if out.minX < 0 { out.origin.x = 0 }
        if out.minY < 0 { out.origin.y = 0 }
        if out.maxX > bounds.maxX { out.origin.x = bounds.maxX - out.width }
        if out.maxY > bounds.maxY { out.origin.y = bounds.maxY - out.height }
        return out
    }

    private func resizeRect(handle: Int, to point: NSPoint) -> NSRect {
        var sel = selectionAtDragStart
        switch handle {
        case 0: // 左下
            sel.size.width += sel.minX - point.x; sel.origin.x = point.x
            sel.size.height += sel.minY - point.y; sel.origin.y = point.y
        case 1: // 右下
            sel.size.width = point.x - sel.minX
            sel.size.height += sel.minY - point.y; sel.origin.y = point.y
        case 2: // 左上
            sel.size.width += sel.minX - point.x; sel.origin.x = point.x
            sel.size.height = point.y - sel.minY
        case 3: // 右上
            sel.size.width = point.x - sel.minX
            sel.size.height = point.y - sel.minY
        case 4: // 下
            sel.size.height += sel.minY - point.y; sel.origin.y = point.y
        case 5: // 右
            sel.size.width = point.x - sel.minX
        case 6: // 上
            sel.size.height = point.y - sel.minY
        case 7: // 左
            sel.size.width += sel.minX - point.x; sel.origin.x = point.x
        default:
            break
        }
        // 防止拖反产生负尺寸
        return sel.standardized
    }
}
