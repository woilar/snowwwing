import AppKit
import ApplicationServices

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    init(frame: CGRect, interactive: Bool) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = !interactive
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + (interactive ? 2 : 1))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        animationBehavior = .none
        isMovable = false
    }
}

final class SnowView: NSView {
    let world: SnowWorld
    init(world: SnowWorld) {
        self.world = world
        super.init(frame: CGRect(origin: .zero, size: world.size))
    }
    required init?(coder: NSCoder) { fatalError("Not used") }
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill(using: .copy)
        drawWinter(world)
    }
}

final class CharacterView: NSView {
    unowned let scene: DesktopScene
    let ball: Snowball?
    private var offset = CGPoint.zero
    private var lastPoint = CGPoint.zero
    private var lastTime: TimeInterval = 0

    init(scene: DesktopScene, ball: Snowball?) {
        self.scene = scene
        self.ball = ball
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel(L10n.text(ball == nil ? "Снегоуборочный транспорт, перетащите мышью" : "Снежок, перетащите к другому, чтобы собрать снеговика"))
    }
    required init?(coder: NSCoder) { fatalError("Not used") }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill(using: .copy)
        if let ball { drawSnowball(ball, in: bounds, infernal: scene.world.infernalMode) }
        else if scene.world.useTractor {
            drawTractor(in: bounds, direction: scene.world.plowDirection, time: scene.world.elapsed,
                        wheelAngle: scene.world.trainWheelAngle, infernal: scene.world.infernalMode)
        } else { drawPlow(in: bounds, direction: scene.world.plowDirection, time: scene.world.elapsed,
                       carriageCount: scene.world.carriageCount, load: scene.world.trainLoad,
                       fire: scene.world.infernalMode ? 1 : scene.world.trainFireIntensity,
                       wheelAngle: scene.world.trainWheelAngle, infernal: scene.world.infernalMode) }
    }

    func mouseInScene() -> CGPoint {
        let p = NSEvent.mouseLocation
        return CGPoint(x: p.x - scene.frame.minX, y: p.y - scene.frame.minY)
    }

    override func mouseDown(with event: NSEvent) {
        let mouse = mouseInScene()
        if let ball {
            ball.dragging = true
            ball.support = nil
            ball.velocity = .zero
            offset = CGPoint(x: mouse.x - ball.point.x, y: mouse.y - ball.point.y)
        } else {
            scene.world.plowDragging = true
            offset = CGPoint(x: mouse.x - scene.world.plowX, y: 0)
        }
        lastPoint = mouse
        lastTime = event.timestamp
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        let mouse = mouseInScene()
        let dt = max(0.008, event.timestamp - lastTime)
        if let ball {
            scene.world.dragBall(ball, to: CGPoint(x: mouse.x - offset.x, y: mouse.y - offset.y))
            offset = CGPoint(x: mouse.x - ball.point.x, y: mouse.y - ball.point.y)
            ball.velocity = CGVector(dx: min(1000, max(-1000, (mouse.x - lastPoint.x) / dt)),
                                     dy: min(1000, max(-1000, (mouse.y - lastPoint.y) / dt)))
        } else {
            if abs(mouse.x - lastPoint.x) > 1 {
                scene.world.plowDirection = mouse.x > lastPoint.x ? 1 : -1
            }
            scene.world.movePlow(to: min(scene.world.size.width, max(0, mouse.x - offset.x)))
        }
        lastTime = event.timestamp
        lastPoint = mouse
        scene.syncCharacters()
    }

    override func mouseUp(with event: NSEvent) {
        if let ball {
            if event.timestamp - lastTime > 0.12 { ball.velocity = .zero }
            scene.world.release(ball)
        } else { scene.world.plowDragging = false }
        NSCursor.openHand.set()
        // Defer destroying the dragged panel until AppKit finishes dispatching this mouse-up.
        DispatchQueue.main.async { [weak self] in self?.scene.syncCharacters() }
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let ball else { return }
        scene.world.burst(at: ball.point, count: 18)
        scene.world.balls.removeAll { $0 === ball }
        DispatchQueue.main.async { [weak self] in self?.scene.syncCharacters() }
    }
}

final class DesktopScene {
    let frame: CGRect
    let world: SnowWorld
    let overlay: OverlayPanel
    var characters: [UUID: OverlayPanel] = [:]
    var plow: OverlayPanel?
    var visible = true

    init(screen: NSScreen) {
        frame = screen.frame
        world = SnowWorld(size: screen.frame.size)
        overlay = OverlayPanel(frame: screen.frame, interactive: false)
        overlay.contentView = SnowView(world: world)
        overlay.orderFrontRegardless()
        syncCharacters()
    }

    func characterPanel(ball: Snowball?) -> OverlayPanel {
        let panel = OverlayPanel(frame: .zero, interactive: true)
        panel.contentView = CharacterView(scene: self, ball: ball)
        return panel
    }

    func syncCharacters() {
        if world.snowfallOnly {
            characters.values.forEach { $0.orderOut(nil) }
            plow?.orderOut(nil)
            overlay.contentView?.needsDisplay = true
            return
        }
        let live = Set(world.balls.map(\.id))
        for id in Array(characters.keys) where !live.contains(id) {
            characters.removeValue(forKey: id)?.close()
        }
        for ball in world.balls {
            let panel = characters[ball.id] ?? characterPanel(ball: ball)
            characters[ball.id] = panel
            panel.setFrame(ball.frame.offsetBy(dx: frame.minX, dy: frame.minY), display: false)
            panel.contentView?.needsDisplay = true
            if visible && !panel.isVisible { panel.orderFrontRegardless() }
        }
        if world.plowActive {
            if plow == nil { plow = characterPanel(ball: nil) }
            plow?.setFrame(world.trainFrame.offsetBy(dx: frame.minX, dy: frame.minY), display: false)
            plow?.contentView?.needsDisplay = true
            if visible && plow?.isVisible == false { plow?.orderFrontRegardless() }
        } else { plow?.orderOut(nil) }
        overlay.contentView?.needsDisplay = true
    }

    func setVisible(_ value: Bool) {
        visible = value
        if value { overlay.orderFrontRegardless(); syncCharacters() }
        else {
            overlay.orderOut(nil)
            characters.values.forEach { $0.orderOut(nil) }
            plow?.orderOut(nil)
        }
    }

    func brush(from previous: CGPoint, to mouse: CGPoint) {
        guard visible else { return }
        world.brushSnow(from: CGPoint(x: previous.x - frame.minX, y: previous.y - frame.minY),
                        to: CGPoint(x: mouse.x - frame.minX, y: mouse.y - frame.minY))
    }

    func close() {
        overlay.close()
        characters.values.forEach { $0.close() }
        characters.removeAll()
        plow?.close()
        plow = nil
    }
}

final class WindowTracker {
    private var dockRect: CGRect?
    private var nextDockRead = Date.distantPast
    private let dockQueue = DispatchQueue(label: "WinterDesktop.Dock", qos: .utility)
    private var dockReadPending = false

    func update(_ scenes: [DesktopScene]) {
        guard let main = NSScreen.screens.first else { return }
        let mainTop = main.frame.maxY
        func cocoaRect(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX, y: mainTop - rect.maxY, width: rect.width, height: rect.height)
        }
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                 kCGNullWindowID) as? [[String: Any]] ?? []
        var roofs: [(String, CGRect)] = []
        var dockWindow: CGRect?
        for info in windows {
            guard let pid = info[kCGWindowOwnerPID as String] as? Int, pid != Int(getpid()),
                  let dict = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: dict as CFDictionary),
                  rect.width > 30, rect.height > 20,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0.1 else { continue }
            let layer = info[kCGWindowLayer as String] as? Int ?? -1
            if layer == 0, let number = info[kCGWindowNumber as String] as? Int {
                roofs.append(("window-\(number)", cocoaRect(rect)))
            }
            if info[kCGWindowOwnerName as String] as? String == "Dock", layer == 20,
               min(rect.width, rect.height) < 180 {
                dockWindow = cocoaRect(rect)
            }
        }
        if !dockReadPending && Date() >= nextDockRead {
            if AXIsProcessTrusted(),
               let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first {
                dockReadPending = true
                let pid = dock.processIdentifier
                dockQueue.async { [weak self] in
                    let rect = Self.readDock(pid: pid)
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.dockRect = rect
                        self.dockReadPending = false
                        self.nextDockRead = Date().addingTimeInterval(0.7)
                    }
                }
            } else {
                dockRect = nil
                nextDockRead = Date().addingTimeInterval(0.7)
            }
        }
        if let rect = dockRect.map(cocoaRect) ?? dockWindow { roofs.insert(("dock", rect), at: 0) }
        for scene in scenes {
            var front: [CGRect] = []
            var ledges: [Ledge] = []
            var hiddenRoofs: Set<String> = []
            let screenTop = NSScreen.screens.first { $0.frame == scene.frame }?.visibleFrame.maxY ?? scene.frame.maxY
            let roofCeiling = min(scene.frame.maxY - 20, screenTop - 1) - scene.frame.minY
            for (id, global) in roofs {
                let local = global.offsetBy(dx: -scene.frame.minX, dy: -scene.frame.minY)
                defer { front.append(local) }
                let hidden = id.hasPrefix("window-") && (local.maxY >= roofCeiling || local.height <= 40)
                if hidden {
                    hiddenRoofs.insert(id)
                }
                guard !hidden, local.maxY > 4, local.maxY < roofCeiling,
                      local.maxX > 0, local.minX < scene.frame.width else { continue }
                let clipped = CGRect(x: max(0, local.minX), y: local.minY,
                                     width: min(scene.frame.width, local.maxX) - max(0, local.minX),
                                     height: local.height)
                let spans = exposedSpans(of: clipped, behind: front)
                if !spans.isEmpty { ledges.append(Ledge(id: id, rect: clipped, spans: spans)) }
            }
            scene.world.setLedges(ledges, hiddenRoofs: hiddenRoofs)
        }
    }

    private static func readDock(pid: pid_t) -> CGRect? {
        let app = AXUIElementCreateApplication(pid)
        let deadline = ProcessInfo.processInfo.systemUptime + 0.2
        var aborted = false
        func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard !aborted, remaining > 0 else { aborted = true; return nil }
            guard AXUIElementSetMessagingTimeout(element, Float(min(0.05, remaining))) == .success else {
                aborted = true
                return nil
            }
            var result: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &result)
            if status == .cannotComplete || status == .invalidUIElement || status == .apiDisabled {
                aborted = true
            }
            guard status == .success else { return nil }
            return result
        }
        func rect(_ element: AXUIElement) -> CGRect? {
            guard let p = value(element, kAXPositionAttribute), let s = value(element, kAXSizeAttribute),
                  CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
            var point = CGPoint.zero, size = CGSize.zero
            guard AXValueGetValue(p as! AXValue, .cgPoint, &point),
                  AXValueGetValue(s as! AXValue, .cgSize, &size), size.width > 0, size.height > 0 else { return nil }
            return CGRect(origin: point, size: size)
        }
        let children = value(app, kAXChildrenAttribute) as? [AXUIElement] ?? []
        for child in children {
            guard !aborted else { return nil }
            guard value(child, kAXRoleAttribute) as? String == kAXListRole else { continue }
            let items = value(child, kAXChildrenAttribute) as? [AXUIElement] ?? []
            let container = rect(child)
            var bounds: [CGRect] = []
            for item in items {
                guard !aborted else { return nil }
                if let bound = rect(item) { bounds.append(bound) }
            }
            guard !aborted else { return nil }
            if let surface = dockSurfaceBounds(container: container, items: bounds) { return surface }
        }
        return nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    var scenes: [DesktopScene] = []
    let tracker = WindowTracker()
    var statusItem: NSStatusItem!
    var timer: Timer?
    var paused = false
    var sleeping = false
    var lastTick = ProcessInfo.processInfo.systemUptime
    var lastScan: TimeInterval = 0
    var previousMouse = NSEvent.mouseLocation
    var pauseItem: NSMenuItem!
    var dockItem: NSMenuItem!
    let accumulationSlider = NSSlider()
    let accumulationLabel = NSTextField(labelWithString: "")
    var accumulationRate: Double = 2
    let transportMenu = NSMenu(title: "Транспорт")
    var useTractor = false
    let snowflakeMenu = NSMenu(title: "Вид снежинок")
    var crystalFlakes = false
    let snowflakeSizeSlider = NSSlider()
    let snowflakeSizeLabel = NSTextField(labelWithString: "")
    var snowflakeSize = 100
    var snowfallOnly = false
    var snowfallOnlyItem: NSMenuItem!
    var infernalMode = false
    var infernalItem: NSMenuItem!
    let languageMenu = NSMenu(title: "Язык")

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            NSApp.terminate(nil)
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        UserDefaults.standard.register(defaults: ["accumulationRate": 2])
        let savedRate = UserDefaults.standard.double(forKey: "accumulationRate")
        accumulationRate = savedRate.isFinite && (1...8).contains(savedRate) ? savedRate : 2
        useTractor = UserDefaults.standard.bool(forKey: "useTractor")
        crystalFlakes = UserDefaults.standard.bool(forKey: "crystalFlakes")
        let savedSize = UserDefaults.standard.integer(forKey: "snowflakeSize")
        snowflakeSize = (50...200).contains(savedSize) ? savedSize : 100
        snowfallOnly = UserDefaults.standard.bool(forKey: "snowfallOnly")
        infernalMode = UserDefaults.standard.bool(forKey: "infernalMode")
        statusItem.button?.image = NSImage(systemSymbolName: "snowflake", accessibilityDescription: "Winter Desktop")
        let menu = NSMenu()
        func item(_ title: String, _ action: Selector) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
            return item
        }
        let title = NSMenuItem(title: "Winter Desktop", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        pauseItem = item("Пауза и скрыть эффекты", #selector(togglePause))
        snowfallOnlyItem = item("Отключить сугробы", #selector(toggleSnowfallOnly))
        snowfallOnlyItem.state = snowfallOnly ? .on : .off
        infernalItem = item("Адский режим", #selector(toggleInfernalMode))
        infernalItem.state = infernalMode ? .on : .off
        func sliderItem(_ title: String, slider: NSSlider, label: NSTextField,
                        value: Double, range: ClosedRange<Double>, action: Selector) -> NSMenuItem {
            let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 60))
            label.frame = NSRect(x: 18, y: 35, width: 244, height: 18)
            label.font = .menuFont(ofSize: 13)
            slider.frame = NSRect(x: 18, y: 8, width: 244, height: 22)
            slider.minValue = range.lowerBound
            slider.maxValue = range.upperBound
            slider.doubleValue = value
            slider.isContinuous = true
            slider.target = self
            slider.action = action
            slider.setAccessibilityLabel(title)
            view.addSubview(label)
            view.addSubview(slider)
            entry.view = view
            return entry
        }
        accumulationLabel.stringValue = String(format: "Скорость накопления: ×%.1f", accumulationRate)
        menu.addItem(sliderItem("Скорость накопления", slider: accumulationSlider, label: accumulationLabel,
                                value: accumulationRate, range: 1...8, action: #selector(changeAccumulation(_:))))
        let transportItem = NSMenuItem(title: "Транспорт", action: nil, keyEquivalent: "")
        transportItem.submenu = transportMenu
        for (tag, title) in ["Паровоз", "Снегоуборочная машина"].enumerated() {
            let option = NSMenuItem(title: title, action: #selector(changeTransport(_:)), keyEquivalent: "")
            option.target = self
            option.tag = tag
            option.state = (tag == 1) == useTractor ? .on : .off
            transportMenu.addItem(option)
        }
        menu.addItem(transportItem)
        let snowflakeItem = NSMenuItem(title: "Вид снежинок", action: nil, keyEquivalent: "")
        snowflakeItem.submenu = snowflakeMenu
        for (tag, title) in ["Мягкие точки", "Снежинки-кристаллы"].enumerated() {
            let option = NSMenuItem(title: title, action: #selector(changeSnowflakes(_:)), keyEquivalent: "")
            option.target = self
            option.tag = tag
            option.state = (tag == 1) == crystalFlakes ? .on : .off
            snowflakeMenu.addItem(option)
        }
        menu.addItem(snowflakeItem)
        snowflakeSizeLabel.stringValue = "Размер снежинок: \(snowflakeSize)%"
        menu.addItem(sliderItem("Размер снежинок", slider: snowflakeSizeSlider, label: snowflakeSizeLabel,
                                value: Double(snowflakeSize), range: 50...200, action: #selector(changeSnowflakeSize(_:))))
        _ = item(infernalMode ? "Добавить череп" : "Добавить снежок", #selector(addBall))
        _ = item("Позвать снегоуборочный транспорт", #selector(startPlow))
        _ = item("Очистить снег", #selector(clearSnow))
        menu.addItem(.separator())
        dockItem = item("Подключить снег на Dock…", #selector(enableDock))
        _ = item("Как играть…", #selector(showHelp))
        let languageItem = NSMenuItem(title: "Язык", action: nil, keyEquivalent: "")
        languageItem.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        languageItem.submenu = languageMenu
        for (tag, title) in ["Русский", "English"].enumerated() {
            let option = NSMenuItem(title: title, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            option.target = self
            option.tag = tag
            languageMenu.addItem(option)
        }
        menu.addItem(languageItem)
        menu.addItem(.separator())
        _ = item("Выйти", #selector(quit))
        statusItem.menu = menu
        refreshLanguage()
        rebuildScreens()
        NotificationCenter.default.addObserver(self, selector: #selector(rebuildScreens),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(didWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        timer = Timer(timeInterval: 1.0 / 30, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
        if CommandLine.arguments.contains("--smoke-test") { smokeTest(self) }
    }

    @objc func rebuildScreens() {
        scenes.forEach { $0.close() }
        scenes = NSScreen.screens.map { DesktopScene(screen: $0) }
        for scene in scenes {
            scene.world.accumulationRate = CGFloat(accumulationRate)
            scene.world.useTractor = useTractor
            scene.world.crystalFlakes = crystalFlakes
            scene.world.snowflakeScale = CGFloat(snowflakeSize) / 100
            scene.world.snowfallOnly = snowfallOnly
            scene.world.infernalMode = infernalMode
            scene.syncCharacters()
        }
        if paused || sleeping { scenes.forEach { $0.setVisible(false) } }
        tracker.update(scenes)
    }

    @objc func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = now - lastTick
        lastTick = now
        let mouse = NSEvent.mouseLocation
        let previous = previousMouse
        previousMouse = mouse
        guard !paused, !sleeping else { return }
        if now - lastScan >= 1.0 / 30 {
            tracker.update(scenes)
            lastScan = now
            dockItem.title = L10n.text(AXIsProcessTrusted() ? "Универсальный доступ разрешён ✓" : "Подключить снег на Dock…")
        }
        for scene in scenes where scene.visible {
            scene.brush(from: previous, to: mouse)
            scene.world.step(CGFloat(dt), allowNewBall: scenes.reduce(0) { $0 + $1.world.balls.count } < 6)
            scene.syncCharacters()
        }
    }

    @objc func togglePause() {
        paused.toggle()
        pauseItem.title = L10n.text(paused ? "Продолжить снегопад" : "Пауза и скрыть эффекты")
        scenes.forEach { $0.setVisible(!paused && !sleeping) }
    }

    @objc func changeAccumulation(_ sender: NSSlider) {
        guard sender.doubleValue.isFinite else { return }
        accumulationRate = (min(8, max(1, sender.doubleValue)) * 10).rounded() / 10
        sender.doubleValue = accumulationRate
        UserDefaults.standard.set(accumulationRate, forKey: "accumulationRate")
        accumulationLabel.stringValue = String(format: L10n.text("Скорость накопления: ×%.1f"), accumulationRate)
        for scene in scenes { scene.world.accumulationRate = CGFloat(accumulationRate) }
    }
    @objc func changeTransport(_ sender: NSMenuItem) {
        guard sender.tag == 0 || sender.tag == 1 else { return }
        useTractor = sender.tag == 1
        UserDefaults.standard.set(useTractor, forKey: "useTractor")
        for option in transportMenu.items { option.state = (option.tag == 1) == useTractor ? .on : .off }
        for scene in scenes {
            scene.world.useTractor = useTractor
            scene.syncCharacters()
        }
    }
    @objc func changeSnowflakes(_ sender: NSMenuItem) {
        guard sender.tag == 0 || sender.tag == 1 else { return }
        crystalFlakes = sender.tag == 1
        UserDefaults.standard.set(crystalFlakes, forKey: "crystalFlakes")
        for option in snowflakeMenu.items { option.state = (option.tag == 1) == crystalFlakes ? .on : .off }
        for scene in scenes {
            scene.world.crystalFlakes = crystalFlakes
            scene.overlay.contentView?.needsDisplay = true
        }
    }
    @objc func toggleSnowfallOnly() {
        snowfallOnly.toggle()
        UserDefaults.standard.set(snowfallOnly, forKey: "snowfallOnly")
        snowfallOnlyItem.state = snowfallOnly ? .on : .off
        for scene in scenes {
            scene.world.snowfallOnly = snowfallOnly
            scene.syncCharacters()
        }
    }
    @objc func changeSnowflakeSize(_ sender: NSSlider) {
        guard sender.doubleValue.isFinite else { return }
        snowflakeSize = Int(min(200, max(50, sender.doubleValue)).rounded())
        sender.doubleValue = Double(snowflakeSize)
        UserDefaults.standard.set(snowflakeSize, forKey: "snowflakeSize")
        snowflakeSizeLabel.stringValue = String(format: L10n.text("Размер снежинок: %d%%"), snowflakeSize)
        for scene in scenes {
            scene.world.snowflakeScale = CGFloat(snowflakeSize) / 100
            scene.overlay.contentView?.needsDisplay = true
        }
    }
    @objc func toggleInfernalMode() {
        infernalMode.toggle()
        UserDefaults.standard.set(infernalMode, forKey: "infernalMode")
        infernalItem.state = infernalMode ? .on : .off
        statusItem.menu?.items.first { $0.action == #selector(addBall) }?.title = L10n.text(infernalMode ? "Добавить череп" : "Добавить снежок")
        for scene in scenes {
            scene.world.infernalMode = infernalMode
            scene.syncCharacters()
        }
    }
    @objc func changeLanguage(_ sender: NSMenuItem) {
        guard sender.tag == 0 || sender.tag == 1 else { return }
        L10n.english = sender.tag == 1
        UserDefaults.standard.set(L10n.english ? "en" : "ru", forKey: "language")
        refreshLanguage()
    }

    func refreshLanguage() {
        func translate(_ menu: NSMenu) {
            menu.title = L10n.text(menu.title)
            for item in menu.items {
                item.title = L10n.text(item.title)
                if let submenu = item.submenu { translate(submenu) }
            }
        }
        if let menu = statusItem.menu { translate(menu) }
        for item in languageMenu.items { item.state = (item.tag == 1) == L10n.english ? .on : .off }
        accumulationLabel.stringValue = String(format: L10n.text("Скорость накопления: ×%.1f"), accumulationRate)
        snowflakeSizeLabel.stringValue = String(format: L10n.text("Размер снежинок: %d%%"), snowflakeSize)
        accumulationSlider.setAccessibilityLabel(L10n.text("Скорость накопления"))
        snowflakeSizeSlider.setAccessibilityLabel(L10n.text("Размер снежинок"))
        for scene in scenes {
            scene.plow?.contentView?.setAccessibilityLabel(L10n.text("Снегоуборочный транспорт, перетащите мышью"))
            for panel in scene.characters.values {
                panel.contentView?.setAccessibilityLabel(L10n.text(scene.world.infernalMode ? "Череп, перетащите мышью" :
                    "Снежок, перетащите к другому, чтобы собрать снеговика"))
            }
        }
    }
    @objc func willSleep() { sleeping = true; scenes.forEach { $0.setVisible(false) } }
    @objc func didWake() { sleeping = false; lastTick = ProcessInfo.processInfo.systemUptime; scenes.forEach { $0.setVisible(!paused) } }
    @objc func addBall() {
        guard !snowfallOnly else { return }
        guard scenes.reduce(0, { $0 + $1.world.balls.count }) < 6 else { return }
        let point = NSEvent.mouseLocation
        let scene = scenes.first { $0.frame.contains(point) } ?? scenes.first
        scene?.world.addBall()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.action != #selector(addBall) || !snowfallOnly
    }
    @objc func startPlow() {
        guard !snowfallOnly else { return }
        scenes.forEach { $0.world.startPlow() }
    }
    @objc func clearSnow() { scenes.forEach { $0.world.resetSnow() } }
    @objc func enableDock() {
        guard !AXIsProcessTrusted() else { return }
        let alert = NSAlert()
        alert.messageText = L10n.text("Универсальный доступ для снега на Dock")
        alert.informativeText = L10n.accessibilityNotice
        alert.addButton(withTitle: L10n.text("Продолжить"))
        alert.addButton(withTitle: L10n.text("Отмена"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc func showHelp() {
        let alert = NSAlert()
        alert.messageText = L10n.text("Собери своего снеговика")
        alert.informativeText = L10n.help
        alert.addButton(withTitle: L10n.text("Понятно"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        scenes.forEach { $0.close() }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
}
