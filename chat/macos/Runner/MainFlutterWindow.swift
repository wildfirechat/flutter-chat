import Cocoa
import FlutterMacOS

/// 自定义交通灯按钮类型。
private enum TrafficLightSymbol {
    case close
    case minimize
    case zoom
}

/// 自定义交通灯按钮。
///
/// 显示逻辑：
/// - 窗口未获得焦点时：三个圆点为浅灰色，不显示图标；
/// - 窗口获得焦点后：三个圆点显示各自颜色（红/黄/绿），不显示图标；
/// - 鼠标悬停在交通灯区域时：三个圆点同时显示颜色+图标（× / − / +），
///   无论当前窗口是否处于焦点状态。
private class TrafficLightButton: NSView {
    private let symbol: TrafficLightSymbol
    private let activeColor: NSColor
    private let pressedColor: NSColor
    private let inactiveColor = NSColor(srgbRed: 0.75, green: 0.75, blue: 0.75, alpha: 1.0)

    private var isKeyWindow = false
    private var isGroupHovered = false
    private var isPressed = false
    private var isSymbolVisible = false

    var onClick: (() -> Void)?

    init(symbol: TrafficLightSymbol, active: NSColor, pressed: NSColor) {
        self.symbol = symbol
        self.activeColor = active
        self.pressedColor = pressed
        super.init(frame: .zero)
        self.wantsLayer = true
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let radius = min(bounds.width, bounds.height) / 2.0
        layer?.cornerRadius = radius
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard isSymbolVisible else { return }

        let size = min(bounds.width, bounds.height)
        let lineLength = size * 0.42
        let lineWidth = size * 0.10
        let centerX = bounds.midX
        let centerY = bounds.midY

        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round

        switch symbol {
        case .close:
            path.move(to: NSPoint(x: centerX - lineLength / 2, y: centerY - lineLength / 2))
            path.line(to: NSPoint(x: centerX + lineLength / 2, y: centerY + lineLength / 2))
            path.move(to: NSPoint(x: centerX + lineLength / 2, y: centerY - lineLength / 2))
            path.line(to: NSPoint(x: centerX - lineLength / 2, y: centerY + lineLength / 2))
        case .minimize:
            path.move(to: NSPoint(x: centerX - lineLength / 2, y: centerY))
            path.line(to: NSPoint(x: centerX + lineLength / 2, y: centerY))
        case .zoom:
            path.move(to: NSPoint(x: centerX - lineLength / 2, y: centerY))
            path.line(to: NSPoint(x: centerX + lineLength / 2, y: centerY))
            path.move(to: NSPoint(x: centerX, y: centerY - lineLength / 2))
            path.line(to: NSPoint(x: centerX, y: centerY + lineLength / 2))
        }

        NSColor.black.withAlphaComponent(0.55).setStroke()
        path.stroke()
    }

    func setWindowKeyState(_ isKey: Bool) {
        self.isKeyWindow = isKey
        updateAppearance()
    }

    func setGroupHovered(_ hovered: Bool) {
        self.isGroupHovered = hovered
        updateAppearance()
    }

    private func updateAppearance() {
        if isPressed {
            layer?.backgroundColor = pressedColor.cgColor
            isSymbolVisible = isGroupHovered
        } else if isGroupHovered {
            layer?.backgroundColor = activeColor.cgColor
            isSymbolVisible = true
        } else if isKeyWindow {
            layer?.backgroundColor = activeColor.cgColor
            isSymbolVisible = false
        } else {
            layer?.backgroundColor = inactiveColor.cgColor
            isSymbolVisible = false
        }
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        updateAppearance()
    }

    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let isInside = bounds.contains(location)
        isPressed = false
        updateAppearance()
        if isInside {
            onClick?()
        }
    }
}

/// 三个交通灯组成的容器，负责横向排布并统管悬停/焦点状态。
private class TrafficLightsView: NSView {
    static let buttonSize: CGFloat = 12
    static let spacing: CGFloat = 7

    private var isKeyWindow = false
    private var trackingArea: NSTrackingArea?

    let closeButton = TrafficLightButton(
        symbol: .close,
        active: NSColor(srgbRed: 1.000, green: 0.231, blue: 0.188, alpha: 1.0),
        pressed: NSColor(srgbRed: 0.898, green: 0.196, blue: 0.157, alpha: 1.0)
    )
    let minimizeButton = TrafficLightButton(
        symbol: .minimize,
        active: NSColor(srgbRed: 1.000, green: 0.741, blue: 0.180, alpha: 1.0),
        pressed: NSColor(srgbRed: 0.898, green: 0.631, blue: 0.157, alpha: 1.0)
    )
    let zoomButton = TrafficLightButton(
        symbol: .zoom,
        active: NSColor(srgbRed: 0.188, green: 0.780, blue: 0.251, alpha: 1.0),
        pressed: NSColor(srgbRed: 0.157, green: 0.678, blue: 0.212, alpha: 1.0)
    )

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(closeButton)
        addSubview(minimizeButton)
        addSubview(zoomButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingArea {
            removeTrackingArea(area)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        if let area = trackingArea {
            addTrackingArea(area)
        }
    }

    func setWindowKeyState(_ isKey: Bool) {
        isKeyWindow = isKey
        closeButton.setWindowKeyState(isKey)
        minimizeButton.setWindowKeyState(isKey)
        zoomButton.setWindowKeyState(isKey)
    }

    private func setGroupHovered(_ hovered: Bool) {
        closeButton.setGroupHovered(hovered)
        minimizeButton.setGroupHovered(hovered)
        zoomButton.setGroupHovered(hovered)
    }

    override func mouseEntered(with event: NSEvent) {
        setGroupHovered(true)
    }

    override func mouseExited(with event: NSEvent) {
        setGroupHovered(false)
    }

    override func layout() {
        super.layout()
        let size = TrafficLightsView.buttonSize
        let gap = TrafficLightsView.spacing
        let totalWidth = size * 3 + gap * 2
        var x = (bounds.width - totalWidth) / 2.0
        let y = (bounds.height - size) / 2.0

        closeButton.frame = NSRect(x: x, y: y, width: size, height: size)
        x += size + gap
        minimizeButton.frame = NSRect(x: x, y: y, width: size, height: size)
        x += size + gap
        zoomButton.frame = NSRect(x: x, y: y, width: size, height: size)
    }
}

class MainFlutterWindow: NSWindow {
    private var trafficLightsView: TrafficLightsView?

    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        // 微信式沉浸标题栏：隐藏系统标题栏，内容延伸到窗口顶部，
        // 使用自定义交通灯按钮，尺寸和悬停效果更接近原生/微信。
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.styleMask.insert(.fullSizeContentView)

        // window_manager 需要接管窗口，取消默认最小尺寸等限制
        RegisterGeneratedPlugins(registry: flutterViewController)

        super.awakeFromNib()
    }

    override func becomeKey() {
        super.becomeKey()
        trafficLightsView?.setWindowKeyState(true)
    }

    override func resignKey() {
        super.resignKey()
        trafficLightsView?.setWindowKeyState(false)
    }

    override func layoutIfNeeded() {
        super.layoutIfNeeded()

        // 隐藏系统默认交通灯，避免和我们自定义的圆点重叠。
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true

        guard let titlebarContainer = self.contentView?.superview?.subviews.first(where: { $0.className == "NSTitlebarContainerView" }) else {
            return
        }

        if trafficLightsView == nil {
            let view = TrafficLightsView(frame: .zero)
            trafficLightsView = view
            titlebarContainer.addSubview(view)

            view.closeButton.onClick = { [weak self] in
                self?.performClose(nil)
            }
            view.minimizeButton.onClick = { [weak self] in
                self?.performMiniaturize(nil)
            }
            view.zoomButton.onClick = { [weak self] in
                self?.performZoom(nil)
            }

            // 初始化一次当前的焦点状态
            view.setWindowKeyState(self.isKeyWindow)
        }

        // 把自定义交通灯放在侧栏顶部左上角，与微信 PC 位置相近。
        let topMargin: CGFloat = 10
        let viewHeight: CGFloat = 24
        let viewWidth: CGFloat = 52
        trafficLightsView?.frame = NSRect(
            x: 8,
            y: titlebarContainer.bounds.height - topMargin - viewHeight,
            width: viewWidth,
            height: viewHeight
        )
    }
}
