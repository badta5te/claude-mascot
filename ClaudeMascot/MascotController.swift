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
    private var currentState: State?
    private var index = 0
    private var timer: Timer?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        animations = [
            .idle:      Animation(frames: Self.cycle("idle"),      interval: 2.5),
            .working:   Animation(frames: Self.cycle("working"),   interval: 1.2),
            .attention: Animation(frames: Self.cycle("attention"), interval: 0.5),
        ]
        super.init()
        buildMenu()
        apply(.idle)
    }

    func apply(_ state: State) {
        guard state != currentState else { return }
        let from = currentState?.rawValue ?? "init"
        Self.log.info("apply \(from, privacy: .public) -> \(state.rawValue, privacy: .public)")
        currentState = state
        statusMenuItem.title = "Status: \(state.rawValue)"
        statusItem.button?.toolTip = "Claude: \(state.rawValue)"
        restartTimer()
        renderFrame()
    }

    private func renderFrame() {
        guard let state = currentState, let anim = animations[state] else { return }
        statusItem.button?.image = anim.frames[index % anim.frames.count]
    }

    private func restartTimer() {
        timer?.invalidate()
        index = 0
        guard let state = currentState, let anim = animations[state] else { return }
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
        addItem(menu, "Open ~/.claude-helper", #selector(openHelperDir(_:)))
        addItem(menu, "Wire up Claude Code hooks…", #selector(wireUpHooks(_:)))
        menu.addItem(.separator())
        addItem(menu, "Uninstall Claude Mascot…", #selector(uninstall(_:)))
        menu.addItem(
            withTitle: "Quit Claude Mascot",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
    }

    private func addItem(_ menu: NSMenu, _ title: String, _ action: Selector) {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        item.target = self
    }

    @objc private func openHelperDir(_ sender: Any?) {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude-helper")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    @objc private func wireUpHooks(_ sender: Any?) {
        Installer.wireUpHooksFromMenu()
    }

    @objc private func uninstall(_ sender: Any?) {
        Installer.uninstallFromMenu()
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
