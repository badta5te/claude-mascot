import AppKit
import os

final class MascotController: NSObject {
    private struct Animation {
        let frames: [NSImage]
        let interval: TimeInterval
    }

    private static let log = Logger(subsystem: "app.claude-mascot", category: "mascot")

    private let statusItem: NSStatusItem
    private let animations: [State: Animation]
    private let statusMenuItem = NSMenuItem(title: "Status: idle", action: nil, keyEquivalent: "")
    private var currentState: State = .idle
    private var index = 0
    private var timer: Timer?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        animations = [
            .idle:      Animation(frames: Self.cycle("idle"),      interval: 1.5),
            .working:   Animation(frames: Self.cycle("working"),   interval: 0.8),
            .attention: Animation(frames: Self.cycle("attention"), interval: 0.22),
        ]
        super.init()
        buildMenu()
        apply(.idle)
    }

    func apply(_ state: State) {
        guard state != currentState else { return }
        Self.log.info("apply \(self.currentState.rawValue, privacy: .public) -> \(state.rawValue, privacy: .public)")
        currentState = state
        statusMenuItem.title = "Status: \(state.rawValue)"
        statusItem.button?.toolTip = "Claude: \(state.rawValue)"
        restartTimer()
        renderFrame()
    }

    private func renderFrame() {
        guard let anim = animations[currentState] else { return }
        statusItem.button?.image = anim.frames[index % anim.frames.count]
    }

    private func restartTimer() {
        timer?.invalidate()
        index = 0
        guard let anim = animations[currentState] else { return }
        timer = Timer.scheduledTimer(withTimeInterval: anim.interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.index += 1
            self.renderFrame()
        }
    }

    private func buildMenu() {
        let menu = NSMenu()
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        let openItem = menu.addItem(
            withTitle: "Open ~/.claude-helper",
            action: #selector(openHelperDir(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Claude Mascot",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
    }

    @objc private func openHelperDir(_ sender: Any?) {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude-helper")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    private static func cycle(_ state: String) -> [NSImage] {
        ["a", "b"].map { Self.image("\(state)-\($0)") }
    }

    private static func image(_ name: String) -> NSImage {
        if let img = NSImage(named: name) { return img }
        let resources = Bundle.main.resourceURL ?? URL(fileURLWithPath: ".")
        let url = resources.appendingPathComponent("\(name).png")
        if let img = NSImage(contentsOf: url) { return img }
        log.error("missing image asset: \(name, privacy: .public)")
        return NSImage(size: NSSize(width: 22, height: 22))
    }
}
