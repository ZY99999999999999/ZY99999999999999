import Cocoa

let appName = "Codex Pet"
let home = FileManager.default.homeDirectoryForCurrentUser
let appDir = URL(fileURLWithPath: CommandLine.arguments.first ?? "").deletingLastPathComponent()
let sessionsURL = home.appendingPathComponent(".codex/sessions")
let shijimaDefaultImageDir = appDir.appendingPathComponent("vendor/Shijima-Qt/DefaultMascot/img")
let userMascotsDir = appDir.appendingPathComponent("mascots")
let petRenderScale: CGFloat = 0.5
let petLogicalSize = NSSize(width: 200, height: 320)
let petWindowSize = NSSize(width: petLogicalSize.width * petRenderScale, height: petLogicalSize.height * petRenderScale)

struct MascotPack {
    let id: String
    let name: String
    let imgDir: URL
}

let defaultMascotPack = MascotPack(id: "builtin:Shijima Default", name: "Shijima Default", imgDir: shijimaDefaultImageDir)

enum PetKind: String, CaseIterable {
    case shijimaDefault = "Shijima Default"
    case mochi = "Mochi"
    case capsule = "Capsule"
}

final class ShijimaSpriteSet {
    let frames: [Int: NSImage]

    init(imageDir: URL) {
        var loaded: [Int: NSImage] = [:]
        for index in 1...46 {
            let url = imageDir.appendingPathComponent("shime\(index).png")
            if let image = NSImage(contentsOf: url) {
                loaded[index] = image
            }
        }
        frames = loaded
    }

    func image(_ index: Int) -> NSImage? {
        frames[index]
    }

    var isAvailable: Bool {
        frames[1] != nil
    }
}

struct PetState {
    var mode: String = "idle"
    var title: String = "Idle"
    var detail: String = "Watching Codex"
    var updatedAt: TimeInterval = Date().timeIntervalSince1970
}

final class SessionWatcher {
    private var sessionURL: URL?
    private var offset: UInt64 = 0
    private var lastRefresh: TimeInterval = 0
    private(set) var state = PetState()

    init() {
        bootstrap()
    }

    func poll() -> [PetState] {
        refreshSessionIfNeeded()
        guard let url = sessionURL else {
            state = PetState(mode: "idle", title: "No Session", detail: "No Codex session file")
            return []
        }

        let size = fileSize(url)
        if size < offset {
            offset = 0
        }
        guard size > offset, let handle = try? FileHandle(forReadingFrom: url) else {
            decayDoneState()
            return []
        }

        handle.seek(toFileOffset: offset)
        let data = handle.readDataToEndOfFile()
        offset = handle.offsetInFile
        try? handle.close()

        let text = String(data: data, encoding: .utf8) ?? ""
        var notices: [PetState] = []
        for line in text.split(separator: "\n") {
            guard let obj = parseJSONLine(String(line)) else { continue }
            let before = state.mode
            apply(obj)
            if ["alert", "done", "error"].contains(state.mode), state.mode != before {
                notices.append(state)
            }
        }
        decayDoneState()
        return notices
    }

    private func bootstrap() {
        guard let newest = newestSession() else { return }
        sessionURL = newest
        state = PetState()
        for line in tailLines(newest, maxBytes: 1_200_000) {
            guard let obj = parseJSONLine(line) else { continue }
            apply(obj)
        }
        offset = fileSize(newest)
        decayDoneState()
    }

    private func refreshSessionIfNeeded() {
        let now = Date().timeIntervalSince1970
        guard now - lastRefresh > 5 else { return }
        lastRefresh = now
        guard let newest = newestSession(), newest != sessionURL else { return }
        sessionURL = newest
        offset = fileSize(newest)
        state = PetState()
        for line in tailLines(newest, maxBytes: 1_200_000) {
            guard let obj = parseJSONLine(line) else { continue }
            apply(obj)
        }
    }

    private func apply(_ obj: [String: Any]) {
        let topType = obj["type"] as? String
        let payload = obj["payload"] as? [String: Any]
        let typ = payload?["type"] as? String
        let now = Date().timeIntervalSince1970

        if looksLikeApproval(obj) {
            state = PetState(mode: "alert", title: "Needs You", detail: "Codex is waiting", updatedAt: now)
            return
        }

        switch typ {
        case "task_started":
            state = PetState(mode: "working", title: "Working", detail: "Codex is running", updatedAt: now)
        case "task_complete":
            state = PetState(mode: "done", title: "Done", detail: "Codex finished this turn", updatedAt: now)
        case "error", "turn_aborted":
            state = PetState(mode: "error", title: "Check Codex", detail: "Codex needs attention", updatedAt: now)
        default:
            if topType == "response_item",
               let ptype = payload?["type"] as? String,
               ["function_call", "custom_tool_call", "web_search_call"].contains(ptype),
               state.mode != "alert" {
                let name = payload?["name"] as? String
                state = PetState(mode: "working", title: "Working", detail: name.map { "Running \($0)" } ?? "Running a tool", updatedAt: now)
            }
        }
    }

    private func decayDoneState() {
        if state.mode == "done", Date().timeIntervalSince1970 - state.updatedAt > 40 {
            state = PetState(mode: "idle", title: "Idle", detail: "Watching Codex")
        }
    }
}

final class PetView: NSView {
    var state = PetState() { didSet { needsDisplay = true } }
    var frameIndex: Int = 0 { didSet { needsDisplay = true } }
    var petKind: PetKind = .shijimaDefault { didSet { needsDisplay = true } }
    var mascotPack: MascotPack = defaultMascotPack {
        didSet {
            shijimaSprites = ShijimaSpriteSet(imageDir: mascotPack.imgDir)
            needsDisplay = true
        }
    }
    var lookRight = false { didSet { needsDisplay = true } }
    private var shijimaSprites = ShijimaSpriteSet(imageDir: shijimaDefaultImageDir)
    private var dragStart: NSPoint?
    private var didDrag = false

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()

        NSGraphicsContext.saveGraphicsState()
        let scale = NSAffineTransform()
        scale.scale(by: petRenderScale)
        scale.concat()

        let (accent, panel, body) = colors(for: state.mode)
        let t = CGFloat(frameIndex)
        let bob = sin(t * 0.22) * 5
        let walk = state.mode == "working" ? sin(t * 0.6) : 0
        let alertShake = state.mode == "alert" ? sin(t * 1.4) * 5 : 0
        let doneHop = state.mode == "done" ? max(0, sin(t * 0.35)) * 8 : 0
        let cx: CGFloat = 100 + alertShake
        let ground: CGFloat = 52
        let y = ground + bob + doneHop

        switch petKind {
        case .shijimaDefault:
            if shijimaSprites.isAvailable {
                drawShijimaDefault(cx: cx, y: y, walk: walk, accent: accent)
            } else {
                drawMissingShijima(accent: accent)
            }
        case .mochi:
            drawMochi(cx: cx, y: y, bob: bob, walk: walk, accent: accent, body: body)
        case .capsule:
            drawCapsule(cx: cx, y: y, bob: bob, walk: walk, accent: accent, body: body)
        }

        let pill = NSBezierPath(roundedRect: NSRect(x: 10, y: 8, width: 180, height: 34), xRadius: 17, yRadius: 17)
        panel.setFill()
        pill.fill()
        accent.setStroke()
        pill.lineWidth = 1.5
        pill.stroke()
        drawCentered(state.title, rect: NSRect(x: 16, y: 23, width: 168, height: 14), size: 11, color: NSColor(calibratedWhite: 0.08, alpha: 1), bold: true)
        drawCentered(short(state.detail), rect: NSRect(x: 16, y: 10, width: 168, height: 12), size: 8, color: NSColor(calibratedWhite: 0.28, alpha: 1), bold: false)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawShijimaDefault(cx: CGFloat, y: CGFloat, walk: CGFloat, accent: NSColor) {
        drawShadow(cx: cx, ground: 46, scale: 0.9)
        let frame = shijimaFrame()
        guard let image = shijimaSprites.image(frame) ?? shijimaSprites.image(1) else { return }
        let size: CGFloat = 178
        let rect = NSRect(x: cx - size / 2, y: y + 8, width: size, height: size)
        drawSprite(image, in: rect, flipped: lookRight)
        drawBadge(accent: accent, at: NSPoint(x: cx + 56, y: y + 170))
    }

    private func shijimaFrame() -> Int {
        switch state.mode {
        case "working":
            let walkFrames = [1, 2, 1, 3]
            return walkFrames[(frameIndex / 4) % walkFrames.count]
        case "done":
            return (frameIndex / 5) % 2 == 0 ? 18 : 19
        case "alert", "error":
            let alertFrames = [5, 7, 9, 7]
            return alertFrames[(frameIndex / 3) % alertFrames.count]
        default:
            let idleFrames = [11, 26, 15, 27, 16, 28, 17, 29, 11]
            return idleFrames[(frameIndex / 16) % idleFrames.count]
        }
    }

    private func drawSprite(_ image: NSImage, in rect: NSRect, flipped: Bool) {
        NSGraphicsContext.saveGraphicsState()
        if flipped {
            let transform = NSAffineTransform()
            transform.translateX(by: rect.midX, yBy: rect.midY)
            transform.scaleX(by: -1, yBy: 1)
            transform.translateX(by: -rect.midX, yBy: -rect.midY)
            transform.concat()
        }
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawMissingShijima(accent: NSColor) {
        let box = NSBezierPath(roundedRect: NSRect(x: 22, y: 84, width: 156, height: 150), xRadius: 18, yRadius: 18)
        NSColor(calibratedWhite: 0.08, alpha: 0.88).setFill()
        box.fill()
        accent.setStroke()
        box.lineWidth = 2
        box.stroke()
        drawCentered("Missing Shijima assets", rect: NSRect(x: 32, y: 150, width: 136, height: 40), size: 12, color: .white, bold: true)
        drawCentered("vendor/Shijima-Qt/DefaultMascot/img", rect: NSRect(x: 32, y: 116, width: 136, height: 26), size: 8, color: NSColor(calibratedWhite: 0.8, alpha: 1), bold: false)
    }

    private func drawMochi(cx: CGFloat, y: CGFloat, bob: CGFloat, walk: CGFloat, accent: NSColor, body: NSColor) {
        drawShadow(cx: cx, ground: 48, scale: 0.95 - min(abs(bob) / 50, 0.10))
        let stretch = state.mode == "working" ? abs(walk) * 8 : 0
        let blob = NSBezierPath(roundedRect: NSRect(x: cx - 58 - stretch / 2, y: y + 34, width: 116 + stretch, height: 116 - stretch / 3), xRadius: 52, yRadius: 52)
        body.setFill()
        blob.fill()
        NSColor(calibratedWhite: 0, alpha: 0.15).setStroke()
        blob.lineWidth = 2
        blob.stroke()

        accent.withAlphaComponent(0.22).setFill()
        NSBezierPath(ovalIn: NSRect(x: cx - 38, y: y + 104, width: 76, height: 28)).fill()

        NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: cx - 28, y: y + 88, width: 13, height: 20)).fill()
        NSBezierPath(ovalIn: NSRect(x: cx + 15, y: y + 88, width: 13, height: 20)).fill()
        NSColor(calibratedRed: 0.90, green: 0.43, blue: 0.48, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: cx - 8, y: y + 75, width: 16, height: 10)).fill()

        drawLittleFoot(x: cx - 33, y: y + 24, swing: -walk, accent: accent)
        drawLittleFoot(x: cx + 33, y: y + 24, swing: walk, accent: accent)
        drawBadge(accent: accent, at: NSPoint(x: cx + 51, y: y + 139))
    }

    private func drawCapsule(cx: CGFloat, y: CGFloat, bob: CGFloat, walk: CGFloat, accent: NSColor, body: NSColor) {
        drawShadow(cx: cx, ground: 46, scale: 1 - min(abs(bob) / 45, 0.12))
        let shell = NSBezierPath(roundedRect: NSRect(x: cx - 43, y: y + 34, width: 86, height: 146), xRadius: 42, yRadius: 42)
        body.setFill()
        shell.fill()
        NSColor(calibratedWhite: 0, alpha: 0.16).setStroke()
        shell.lineWidth = 2
        shell.stroke()

        accent.withAlphaComponent(0.88).setFill()
        NSBezierPath(roundedRect: NSRect(x: cx - 43, y: y + 110, width: 86, height: 70), xRadius: 40, yRadius: 40).fill()
        NSColor.white.withAlphaComponent(0.80).setFill()
        NSBezierPath(roundedRect: NSRect(x: cx - 24, y: y + 132, width: 48, height: 22), xRadius: 11, yRadius: 11).fill()

        NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: cx - 24, y: y + 95, width: 11, height: 18)).fill()
        NSBezierPath(ovalIn: NSRect(x: cx + 13, y: y + 95, width: 11, height: 18)).fill()
        NSColor(calibratedRed: 0.88, green: 0.42, blue: 0.40, alpha: 1).setStroke()
        let mouth = NSBezierPath()
        mouth.move(to: NSPoint(x: cx - 8, y: y + 80))
        mouth.curve(to: NSPoint(x: cx + 8, y: y + 80), controlPoint1: NSPoint(x: cx - 3, y: y + 74), controlPoint2: NSPoint(x: cx + 3, y: y + 74))
        mouth.lineWidth = 2
        mouth.stroke()

        drawLittleFoot(x: cx - 24, y: y + 20, swing: -walk, accent: accent)
        drawLittleFoot(x: cx + 24, y: y + 20, swing: walk, accent: accent)
        drawBadge(accent: accent, at: NSPoint(x: cx + 50, y: y + 170))
    }

    private func drawShadow(cx: CGFloat, ground: CGFloat, scale: CGFloat) {
        NSColor(calibratedWhite: 0, alpha: 0.18).setFill()
        NSBezierPath(ovalIn: NSRect(x: cx - 48 * scale, y: ground, width: 96 * scale, height: 14)).fill()
    }

    private func drawBody(cx: CGFloat, y: CGFloat, color: NSColor, accent: NSColor) {
        let bodyPath = NSBezierPath(roundedRect: NSRect(x: cx - 42, y: y + 34, width: 84, height: 96), xRadius: 34, yRadius: 34)
        color.setFill()
        bodyPath.fill()
        NSColor(calibratedWhite: 0, alpha: 0.16).setStroke()
        bodyPath.lineWidth = 2
        bodyPath.stroke()

        let bib = NSBezierPath(roundedRect: NSRect(x: cx - 24, y: y + 56, width: 48, height: 58), xRadius: 18, yRadius: 18)
        NSColor.white.setFill()
        bib.fill()
        accent.setStroke()
        bib.lineWidth = 2
        bib.stroke()
        drawCentered("10", rect: NSRect(x: cx - 20, y: y + 70, width: 40, height: 28), size: 22, color: NSColor(calibratedWhite: 0.08, alpha: 1), bold: true)
    }

    private func drawHead(cx: CGFloat, y: CGFloat) {
        let head = NSBezierPath(ovalIn: NSRect(x: cx - 50, y: y - 38, width: 100, height: 88))
        NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.68, alpha: 1).setFill()
        head.fill()
        NSColor(calibratedWhite: 0, alpha: 0.14).setStroke()
        head.lineWidth = 2
        head.stroke()

        NSColor(calibratedRed: 0.25, green: 0.16, blue: 0.10, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: cx - 49, y: y + 9, width: 98, height: 48)).fill()
        NSBezierPath(ovalIn: NSRect(x: cx - 38, y: y - 1, width: 44, height: 52)).fill()
        NSBezierPath(ovalIn: NSRect(x: cx - 2, y: y + 0, width: 44, height: 50)).fill()

        let leftEar = NSBezierPath(ovalIn: NSRect(x: cx - 62, y: y - 10, width: 28, height: 34))
        let rightEar = NSBezierPath(ovalIn: NSRect(x: cx + 34, y: y - 10, width: 28, height: 34))
        NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.64, alpha: 1).setFill()
        leftEar.fill()
        rightEar.fill()
    }

    private func drawFace(cx: CGFloat, y: CGFloat) {
        NSColor(calibratedWhite: 0.06, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: cx - 24, y: y - 6, width: 10, height: 22)).fill()
        NSBezierPath(ovalIn: NSRect(x: cx + 14, y: y - 6, width: 10, height: 22)).fill()

        NSColor(calibratedRed: 0.22, green: 0.14, blue: 0.09, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: cx - 33, y: y + 22, width: 28, height: 10), xRadius: 5, yRadius: 5).fill()
        NSBezierPath(roundedRect: NSRect(x: cx + 5, y: y + 22, width: 28, height: 10), xRadius: 5, yRadius: 5).fill()

        NSColor(calibratedRed: 0.92, green: 0.48, blue: 0.42, alpha: 1).setStroke()
        let smile = NSBezierPath()
        smile.move(to: NSPoint(x: cx - 11, y: y - 20))
        smile.curve(to: NSPoint(x: cx + 11, y: y - 20), controlPoint1: NSPoint(x: cx - 4, y: y - 27), controlPoint2: NSPoint(x: cx + 4, y: y - 27))
        smile.lineWidth = 2
        smile.stroke()
    }

    private func drawArm(x: CGFloat, y: CGFloat, swing: CGFloat, flipped: Bool, accent: NSColor) {
        let dx = swing * 7 * (flipped ? -1 : 1)
        let arm = NSBezierPath(roundedRect: NSRect(x: x - 9 + dx, y: y - 40, width: 18, height: 60), xRadius: 9, yRadius: 9)
        NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.64, alpha: 1).setFill()
        arm.fill()
        NSColor(calibratedWhite: 0, alpha: 0.12).setStroke()
        arm.lineWidth = 1.5
        arm.stroke()
        accent.withAlphaComponent(0.45).setFill()
        NSBezierPath(roundedRect: NSRect(x: x - 11 + dx, y: y + 3, width: 22, height: 18), xRadius: 8, yRadius: 8).fill()
    }

    private func drawLeg(x: CGFloat, y: CGFloat, swing: CGFloat, accent: NSColor) {
        let dx = swing * 8
        NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: x - 12 + dx, y: y, width: 24, height: 50), xRadius: 10, yRadius: 10).fill()
        NSBezierPath(roundedRect: NSRect(x: x - 18 + dx * 1.4, y: y - 9, width: 36, height: 18), xRadius: 9, yRadius: 9).fill()
        accent.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: NSRect(x: x - 10 + dx, y: y + 28, width: 20, height: 12), xRadius: 5, yRadius: 5).fill()
    }

    private func drawLittleFoot(x: CGFloat, y: CGFloat, swing: CGFloat, accent: NSColor) {
        let dx = swing * 5
        NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: x - 18 + dx, y: y, width: 36, height: 16), xRadius: 8, yRadius: 8).fill()
        accent.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: NSRect(x: x - 10 + dx, y: y + 6, width: 20, height: 6), xRadius: 3, yRadius: 3).fill()
    }

    private func drawBadge(accent: NSColor, at point: NSPoint) {
        let badge = NSBezierPath(ovalIn: NSRect(x: point.x - 22, y: point.y - 22, width: 44, height: 44))
        accent.setFill()
        badge.fill()
        NSColor.white.setStroke()
        badge.lineWidth = 2
        badge.stroke()
        let badgeText = ["idle": "OK", "working": "...", "done": "✓", "alert": "!", "error": "!"][state.mode] ?? "OK"
        drawCentered(badgeText, rect: NSRect(x: point.x - 21, y: point.y - 9, width: 42, height: 22), size: 18, color: .white, bold: true)
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            activateCodex()
            return
        }
        dragStart = event.locationInWindow
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let start = dragStart else { return }
        let current = event.locationInWindow
        if abs(current.x - start.x) > 3 || abs(current.y - start.y) > 3 {
            didDrag = true
        }
        var origin = window.frame.origin
        origin.x += current.x - start.x
        origin.y += current.y - start.y
        window.setFrameOrigin(origin)
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag {
            activateCodex()
        }
        dragStart = nil
        didDrag = false
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let delegate = NSApp.delegate as? AppDelegate
        let openItem = NSMenuItem(title: "Open Codex", action: #selector(AppDelegate.openCodex), keyEquivalent: "")
        openItem.target = delegate
        menu.addItem(openItem)
        let testItem = NSMenuItem(title: "Test Alert", action: #selector(AppDelegate.testAlert), keyEquivalent: "")
        testItem.target = delegate
        menu.addItem(testItem)
        let petMenu = NSMenu()
        for pack in availableMascotPacks() {
            let item = NSMenuItem(title: pack.name, action: #selector(AppDelegate.chooseMascotPack(_:)), keyEquivalent: "")
            item.target = delegate
            item.representedObject = pack.id
            item.state = petKind == .shijimaDefault && pack.id == mascotPack.id ? .on : .off
            petMenu.addItem(item)
        }
        petMenu.addItem(.separator())
        for kind in [PetKind.mochi, PetKind.capsule] {
            let item = NSMenuItem(title: kind.rawValue, action: #selector(AppDelegate.chooseBuiltInPet(_:)), keyEquivalent: "")
            item.target = delegate
            item.representedObject = kind.rawValue
            item.state = kind == petKind ? .on : .off
            petMenu.addItem(item)
        }
        let chooseItem = NSMenuItem(title: "Choose Pet", action: nil, keyEquivalent: "")
        menu.setSubmenu(petMenu, for: chooseItem)
        menu.addItem(chooseItem)
        let openMascotsItem = NSMenuItem(title: "Open Mascots Folder", action: #selector(AppDelegate.openMascotsFolder), keyEquivalent: "")
        openMascotsItem.target = delegate
        menu.addItem(openMascotsItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func colors(for mode: String) -> (NSColor, NSColor, NSColor) {
        switch mode {
        case "working":
            return (NSColor(calibratedRed: 0.15, green: 0.44, blue: 0.75, alpha: 1), NSColor(calibratedRed: 0.92, green: 0.96, blue: 1, alpha: 1), NSColor(calibratedRed: 0.55, green: 0.78, blue: 1.0, alpha: 1))
        case "done":
            return (NSColor(calibratedRed: 0.18, green: 0.65, blue: 0.42, alpha: 1), NSColor(calibratedRed: 0.91, green: 0.98, blue: 0.94, alpha: 1), NSColor(calibratedRed: 0.60, green: 0.88, blue: 0.68, alpha: 1))
        case "alert":
            return (NSColor(calibratedRed: 0.91, green: 0.30, blue: 0.16, alpha: 1), NSColor(calibratedRed: 1, green: 0.94, blue: 0.90, alpha: 1), NSColor(calibratedRed: 1.0, green: 0.67, blue: 0.48, alpha: 1))
        case "error":
            return (NSColor(calibratedRed: 0.85, green: 0.25, blue: 0.36, alpha: 1), NSColor(calibratedRed: 1, green: 0.94, blue: 0.96, alpha: 1), NSColor(calibratedRed: 1.0, green: 0.56, blue: 0.66, alpha: 1))
        default:
            return (NSColor(calibratedWhite: 0.34, alpha: 1), NSColor(calibratedWhite: 0.96, alpha: 1), NSColor(calibratedRed: 0.74, green: 0.82, blue: 0.88, alpha: 1))
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var view: PetView!
    private var watcher: SessionWatcher!
    private var pollTimer: Timer!
    private var animationTimer: Timer!
    private var velocityX: CGFloat = 1.5

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        watcher = SessionWatcher()
        view = PetView(frame: NSRect(x: 0, y: 0, width: petWindowSize.width, height: petWindowSize.height))
        restorePetChoice()
        view.state = watcher.state
        window = NSWindow(contentRect: NSRect(x: 60, y: 420, width: petWindowSize.width, height: petWindowSize.height), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let notices = self.watcher.poll()
            self.view.state = self.watcher.state
            for notice in notices {
                notify(title: "\(appName): \(notice.title)", message: notice.detail, sound: notice.mode == "alert" || notice.mode == "error")
            }
        }

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.animate()
        }
    }

    @objc func openCodex() {
        activateCodex()
    }

    @objc func testAlert() {
        view.state = PetState(mode: "alert", title: "Needs You", detail: "Codex is waiting")
        notify(title: "\(appName): Needs You", message: "Codex is waiting", sound: true)
    }

    @objc func chooseBuiltInPet(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let kind = PetKind(rawValue: raw) else { return }
        view.petKind = kind
        UserDefaults.standard.set("builtin:\(kind.rawValue)", forKey: "CodexPet.choice")
    }

    @objc func chooseMascotPack(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let pack = availableMascotPacks().first(where: { $0.id == id }) else { return }
        view.petKind = .shijimaDefault
        view.mascotPack = pack
        UserDefaults.standard.set(pack.id, forKey: "CodexPet.choice")
    }

    @objc func openMascotsFolder() {
        try? FileManager.default.createDirectory(at: userMascotsDir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(userMascotsDir)
    }

    private func restorePetChoice() {
        let choice = UserDefaults.standard.string(forKey: "CodexPet.choice")
            ?? UserDefaults.standard.string(forKey: "CodexPet.kind")
            ?? defaultMascotPack.id
        if choice == "builtin:Mochi" || choice == PetKind.mochi.rawValue {
            view.petKind = .mochi
            return
        }
        if choice == "builtin:Capsule" || choice == PetKind.capsule.rawValue {
            view.petKind = .capsule
            return
        }
        if let pack = availableMascotPacks().first(where: { $0.id == choice || $0.name == choice }) {
            view.petKind = .shijimaDefault
            view.mascotPack = pack
            return
        }
        view.petKind = .shijimaDefault
        view.mascotPack = defaultMascotPack
    }

    private func animate() {
        view.frameIndex += 1
        guard let screen = window.screen ?? NSScreen.main else { return }
        var frame = window.frame
        let bounds = screen.visibleFrame

        switch view.state.mode {
        case "working":
            frame.origin.x += velocityX
            view.lookRight = velocityX > 0
            if frame.maxX > bounds.maxX || frame.minX < bounds.minX {
                velocityX *= -1
                view.lookRight = velocityX > 0
                frame.origin.x = min(max(frame.origin.x, bounds.minX), bounds.maxX - frame.width)
            }
        case "alert":
            frame.origin.x += sin(CGFloat(view.frameIndex) * 1.3) * 2.2
        default:
            break
        }

        if frame.minY < bounds.minY { frame.origin.y = bounds.minY }
        if frame.maxY > bounds.maxY { frame.origin.y = bounds.maxY - frame.height }
        window.setFrameOrigin(frame.origin)
    }
}

func newestSession() -> URL? {
    guard let enumerator = FileManager.default.enumerator(at: sessionsURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
        return nil
    }
    var newest: (URL, Date)?
    for case let url as URL in enumerator where url.pathExtension == "jsonl" {
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        if newest == nil || date > newest!.1 {
            newest = (url, date)
        }
    }
    return newest?.0
}

func availableMascotPacks() -> [MascotPack] {
    var packs = [defaultMascotPack]
    try? FileManager.default.createDirectory(at: userMascotsDir, withIntermediateDirectories: true)
    let urls = (try? FileManager.default.contentsOfDirectory(at: userMascotsDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
    for url in urls.sorted(by: { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }) {
        guard isMascotDirectory(url) else { continue }
        let name = url.deletingPathExtension().lastPathComponent
        packs.append(MascotPack(id: url.path, name: name, imgDir: url.appendingPathComponent("img")))
    }
    return packs
}

func isMascotDirectory(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        return false
    }
    let imgDir = url.appendingPathComponent("img")
    let shime1 = imgDir.appendingPathComponent("shime1.png")
    let actions = url.appendingPathComponent("actions.xml")
    return FileManager.default.fileExists(atPath: shime1.path)
        && FileManager.default.fileExists(atPath: actions.path)
}

func fileSize(_ url: URL) -> UInt64 {
    ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value) ?? 0
}

func tailLines(_ url: URL, maxBytes: UInt64) -> [String] {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
    let size = fileSize(url)
    handle.seek(toFileOffset: size > maxBytes ? size - maxBytes : 0)
    let data = handle.readDataToEndOfFile()
    try? handle.close()
    let text = String(data: data, encoding: .utf8) ?? ""
    return text.split(separator: "\n").map(String.init).suffix(300).map { $0 }
}

func parseJSONLine(_ line: String) -> [String: Any]? {
    guard let data = line.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data),
          let dict = obj as? [String: Any] else {
        return nil
    }
    return dict
}

func looksLikeApproval(_ obj: [String: Any]) -> Bool {
    let payload = obj["payload"] as? [String: Any]
    let typ = payload?["type"] as? String
    let alertTypes: Set<String> = ["approval_request", "approval_requested", "permission_request", "confirmation_request", "confirm_request", "user_approval_requested", "tool_approval_requested"]
    if let typ, alertTypes.contains(typ) { return true }
    if payload?["approval_id"] != nil || payload?["permission_id"] != nil || payload?["confirmation_id"] != nil { return true }
    guard obj["type"] as? String == "event_msg" else { return false }
    let ignored: Set<String> = ["user_message", "agent_message", "task_started", "task_complete", "token_count", "patch_apply_end", "exec_command_end", "web_search_end", "mcp_tool_call_end", "context_compacted"]
    if let typ, ignored.contains(typ) || typ.hasSuffix("_end") { return false }
    guard let payload, let data = try? JSONSerialization.data(withJSONObject: payload), let text = String(data: data, encoding: .utf8)?.lowercased() else { return false }
    return ["approval", "approve", "permission", "confirm", "待审批", "审批", "确认"].contains { text.contains($0) }
}

func drawCentered(_ text: String, rect: NSRect, size: CGFloat, color: NSColor, bold: Bool) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
    (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
}

func short(_ text: String) -> String {
    if text.count <= 32 { return text }
    return String(text.prefix(31)) + "..."
}

func activateCodex() {
    let codexURL = URL(fileURLWithPath: "/Applications/Codex.app")
    if let running = NSWorkspace.shared.runningApplications.first(where: { app in
        app.bundleURL == codexURL || app.bundleIdentifier == "com.openai.codex" || app.localizedName == "Codex"
    }) {
        running.activate(options: [.activateAllWindows])
        return
    }

    if #available(macOS 10.15, *) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: codexURL, configuration: configuration)
        return
    }

    NSWorkspace.shared.open(codexURL)
}

func notify(title: String, message: String, sound: Bool) {
    let notification = NSUserNotification()
    notification.title = title
    notification.informativeText = message
    notification.soundName = sound ? NSUserNotificationDefaultSoundName : nil
    NSUserNotificationCenter.default.deliver(notification)
    if sound {
        NSSound(named: NSSound.Name("Glass"))?.play()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
