// EyeBreak — menu bar app for 20-20-20 eye breaks.
// After 20 minutes of screen time, an overlay asks you to look 20 ft away for 20 s.
// The clock restarts whenever you lock the screen or the Mac or display sleeps.
// Event-driven: no polling.
import Cocoa

let workMinutes = Double(CommandLine.arguments.dropFirst().first ?? "") ?? 20
let breakSeconds = 20       // how long the overlay stays up
func screenLocked() -> Bool {
    (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool ?? false
}

final class OverlayPanel: NSPanel {
    var onEsc: () -> Void = {}
    override var canBecomeKey: Bool { true }
    override func keyDown(with event: NSEvent) { if event.keyCode == 53 { onEsc() } }  // Esc skips
}

final class Backdrop: NSVisualEffectView {
    var onClick: () -> Void = {}
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick() }
}

final class EyeBreak: NSObject, NSMenuDelegate {
    private let defaults = UserDefaults(suiteName: "local.eyebreak")!
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
    private var clockStart = Date()   // start of the current stretch of screen time
    private var breakTimer: Timer?    // fires when the stretch reaches workMinutes
    private var paused = false        // screen locked or asleep
    private var panels: [OverlayPanel] = []
    private var countdowns: [NSTextField] = []
    private var countdownTimer: Timer?
    private var remaining = 0

    private var enabled: Bool { !defaults.bool(forKey: "disabled") }

    override init() {
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusLine.isEnabled = false
        enabledItem.target = self
        let breakNow = NSMenuItem(title: "Take a Break Now", action: #selector(takeBreakNow), keyEquivalent: "")
        breakNow.target = self
        let quit = NSMenuItem(title: "Quit EyeBreak", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        for item in [statusLine, .separator(), enabledItem, breakNow, .separator(), quit] { menu.addItem(item) }
        statusItem.menu = menu
        updateIcon()

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(pause), name: NSWorkspace.willSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(pause), name: NSWorkspace.screensDidSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(resume), name: NSWorkspace.didWakeNotification, object: nil)
        ws.addObserver(self, selector: #selector(resume), name: NSWorkspace.screensDidWakeNotification, object: nil)
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(self, selector: #selector(pause), name: .init("com.apple.screenIsLocked"), object: nil)
        dnc.addObserver(self, selector: #selector(resume), name: .init("com.apple.screenIsUnlocked"), object: nil)

        restartClock()
    }

    // MARK: Clock

    @objc private func pause() { paused = true; breakTimer?.invalidate(); breakTimer = nil }

    @objc private func resume() {
        paused = screenLocked()  // waking can land on the lock screen; the unlock event resumes us then
        restartClock()
    }

    private func restartClock() {
        breakTimer?.invalidate(); breakTimer = nil
        clockStart = Date()
        guard enabled, !paused, panels.isEmpty else { return }
        breakTimer = Timer(timeInterval: workMinutes * 60, target: self, selector: #selector(breakDue),
                           userInfo: nil, repeats: false)
        breakTimer!.tolerance = 5
        RunLoop.main.add(breakTimer!, forMode: .common)
    }

    @objc private func breakDue() {
        if screenLocked() { restartClock(); return }  // safety net in case a lock event was missed
        showBreak()
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        enabledItem.state = enabled ? .on : .off
        if !enabled {
            statusLine.title = "Eye breaks are off"
        } else {
            let left = workMinutes * 60 - Date().timeIntervalSince(clockStart)
            statusLine.title = "Next break in \(max(Int((left / 60).rounded(.up)), 1)) min"
        }
    }

    @objc private func toggleEnabled() {
        defaults.set(enabled, forKey: "disabled")
        updateIcon()
        restartClock()
    }

    @objc private func takeBreakNow() { showBreak() }

    private func updateIcon() {
        statusItem.button?.image = NSImage(systemSymbolName: enabled ? "eye" : "eye.slash",
                                           accessibilityDescription: "EyeBreak")
    }

    // MARK: Overlay

    private func label(_ text: String, _ font: NSFont, alpha: CGFloat = 1) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = font
        l.textColor = NSColor.white.withAlphaComponent(alpha)
        l.alignment = .center
        return l
    }

    private func showBreak() {
        guard panels.isEmpty else { return }
        breakTimer?.invalidate(); breakTimer = nil
        for screen in NSScreen.screens {
            let panel = OverlayPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isOpaque = false
            panel.backgroundColor = NSColor.black.withAlphaComponent(0.35)
            panel.hasShadow = false
            panel.alphaValue = 0
            panel.onEsc = { [weak self] in self?.endBreak(chime: false) }

            let backdrop = Backdrop()
            backdrop.material = .fullScreenUI
            backdrop.blendingMode = .behindWindow
            backdrop.state = .active
            backdrop.appearance = NSAppearance(named: .darkAqua)
            backdrop.onClick = { [weak self] in self?.endBreak(chime: false) }
            panel.contentView = backdrop

            let countdown = label("\(breakSeconds)", .monospacedDigitSystemFont(ofSize: 72, weight: .thin))
            countdowns.append(countdown)
            let stack = NSStackView(views: [
                label("👀", .systemFont(ofSize: 96)),
                label("Eye break", .systemFont(ofSize: 52, weight: .semibold)),
                label("Look at something 20 feet (6 m) away", .systemFont(ofSize: 24), alpha: 0.85),
                countdown,
                label("Click or press Esc to skip", .systemFont(ofSize: 14), alpha: 0.5),
            ])
            stack.orientation = .vertical
            stack.spacing = 14
            stack.translatesAutoresizingMaskIntoConstraints = false
            backdrop.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: backdrop.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: backdrop.centerYAnchor),
            ])

            panel.setFrame(screen.frame, display: false)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        panels.first?.makeKey()  // so Esc works without stealing app focus

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6
            panels.forEach { $0.animator().alphaValue = 1 }
        }
        remaining = breakSeconds
        countdownTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(countdownTick),
                                              userInfo: nil, repeats: true)
    }

    @objc private func countdownTick() {
        remaining -= 1
        countdowns.forEach { $0.stringValue = "\(max(remaining, 0))" }
        if remaining <= 0 { endBreak(chime: true) }
    }

    private func endBreak(chime: Bool) {
        guard let timer = countdownTimer else { return }  // already ending
        timer.invalidate()
        countdownTimer = nil
        if chime { NSSound(named: "Glass")?.play() }  // audible "done" — you're looking away, after all
        let closing = panels
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.5
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: { [weak self] in
            closing.forEach { $0.orderOut(nil) }
            self?.panels = []
            self?.countdowns = []
            self?.restartClock()
        })
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // menu bar only, no Dock icon
let eyeBreak = EyeBreak()
app.run()
