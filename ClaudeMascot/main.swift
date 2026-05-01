import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mascot: MascotController?
    private var watcher: StateWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mascot = MascotController()
        Installer.installIfNeeded()
        let watcher = StateWatcher { state in mascot.apply(state) }
        watcher.start()
        self.mascot = mascot
        self.watcher = watcher
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
