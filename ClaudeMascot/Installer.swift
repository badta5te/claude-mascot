import AppKit
import os

enum Installer {
    private static let log = Logger(subsystem: "app.claude-mascot", category: "installer")

    private static let home = FileManager.default.homeDirectoryForCurrentUser
    private static let helperDir   = home.appendingPathComponent(".claude-helper")
    private static let hooksDir    = helperDir.appendingPathComponent("hooks")
    private static let settingsURL = home.appendingPathComponent(".claude/settings.json")

    private static let hookEvents: [(event: String, file: String)] = [
        ("UserPromptSubmit", "set-working.sh"),
        ("PreToolUse",       "set-working.sh"),
        ("PostToolUse",      "set-working.sh"),
        ("Notification",     "set-attention.sh"),
        ("Stop",             "clear.sh"),
    ]

    static func installIfNeeded() {
        // Already wired up — silently refresh hook scripts so an updated app
        // ships its bundled hooks to ~/.claude-helper/hooks/.
        if hooksAlreadyConfigured() {
            do { try syncHookScripts() } catch { log.error("sync failed: \(error.localizedDescription, privacy: .public)") }
            log.debug("hooks already configured; scripts re-synced")
            return
        }
        promptAndInstall()
    }

    static func wireUpHooksFromMenu() {
        if hooksAlreadyConfigured() {
            let a = NSAlert()
            a.messageText = "Hooks already wired up."
            a.informativeText = "Settings already include Claude Mascot's hook entries; nothing to do."
            a.runModal()
            return
        }
        promptAndInstall()
    }

    static func uninstallFromMenu() {
        let alert = NSAlert()
        alert.messageText = "Uninstall Claude Mascot?"
        alert.informativeText = """
            This will:
              • remove Claude Mascot's hook entries from ~/.claude/settings.json (other entries are kept)
              • delete ~/.claude-helper/
              • quit the app

            To finish, drag /Applications/ClaudeMascot.app to the Trash.
            """
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try removeFromSettings()
            try? FileManager.default.removeItem(at: helperDir)
            log.info("uninstall complete")
        } catch {
            log.error("uninstall failed: \(error.localizedDescription, privacy: .public)")
            let oops = NSAlert()
            oops.alertStyle = .warning
            oops.messageText = "Uninstall partially failed."
            oops.informativeText = error.localizedDescription
            oops.runModal()
        }
        NSApp.terminate(nil)
    }

    private static func promptAndInstall() {
        let alert = NSAlert()
        alert.messageText = "Wire up Claude Code hooks?"
        alert.informativeText = """
            Claude Mascot needs to:
              • copy hook scripts to ~/.claude-helper/hooks/
              • add hook entries to ~/.claude/settings.json (a timestamped backup is saved)

            This is what tells the mascot when Claude is working, blocked, or idle.
            """
        alert.addButton(withTitle: "Wire up hooks")
        alert.addButton(withTitle: "Not now")
        alert.alertStyle = .informational
        guard alert.runModal() == .alertFirstButtonReturn else {
            log.info("user declined hook install")
            return
        }

        do {
            try syncHookScripts()
            try mergeSettings()
            log.info("hooks installed")
            let done = NSAlert()
            done.messageText = "Hooks wired up."
            done.informativeText = "Restart any open Claude Code sessions so they pick up the hooks. New sessions get them automatically."
            done.runModal()
        } catch {
            log.error("install failed: \(error.localizedDescription, privacy: .public)")
            let oops = NSAlert()
            oops.alertStyle = .warning
            oops.messageText = "Couldn't wire up hooks."
            oops.informativeText = error.localizedDescription
            oops.runModal()
        }
    }

    private static func hooksAlreadyConfigured() -> Bool {
        guard
            let data = try? Data(contentsOf: settingsURL),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let hooks = json["hooks"] as? [String: Any]
        else { return false }
        for (event, file) in hookEvents {
            let cmd = hooksDir.appendingPathComponent(file).path
            guard let entries = hooks[event] as? [[String: Any]] else { return false }
            let commands = entries.flatMap { entry -> [String] in
                (entry["hooks"] as? [[String: Any]])?.compactMap { $0["command"] as? String } ?? []
            }
            if !commands.contains(cmd) { return false }
        }
        return true
    }

    private static func syncHookScripts() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: hooksDir, withIntermediateDirectories: true)
        guard let bundleHooks = Bundle.main.resourceURL?.appendingPathComponent("hooks"),
              fm.fileExists(atPath: bundleHooks.path)
        else { throw InstallError.bundleResourcesMissing }
        let scripts = (try fm.contentsOfDirectory(atPath: bundleHooks.path))
            .filter { $0.hasSuffix(".sh") }
        for name in scripts {
            let src = bundleHooks.appendingPathComponent(name)
            let dst = hooksDir.appendingPathComponent(name)
            if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
            try fm.copyItem(at: src, to: dst)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dst.path)
        }
    }

    private static func mergeSettings() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL) {
            try? backup(data: data, suffix: "install")
            if let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                json = parsed
            }
        }
        var hooks = (json["hooks"] as? [String: Any]) ?? [:]
        for (event, file) in hookEvents {
            let cmd = hooksDir.appendingPathComponent(file).path
            var entries = (hooks[event] as? [[String: Any]]) ?? []
            let existing = Set(entries.flatMap { entry -> [String] in
                (entry["hooks"] as? [[String: Any]])?.compactMap { $0["command"] as? String } ?? []
            })
            if !existing.contains(cmd) {
                entries.append(["hooks": [["type": "command", "command": cmd]]])
                hooks[event] = entries
            }
        }
        json["hooks"] = hooks
        try atomicWrite(json: json, to: settingsURL)
    }

    private static func removeFromSettings() throws {
        guard
            let data = try? Data(contentsOf: settingsURL),
            var json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        try? backup(data: data, suffix: "uninstall")
        guard var hooks = json["hooks"] as? [String: Any] else { return }
        let prefix = hooksDir.path + "/"
        for event in Array(hooks.keys) {
            guard var entries = hooks[event] as? [[String: Any]] else { continue }
            entries = entries.filter { entry in
                guard let inner = entry["hooks"] as? [[String: Any]] else { return true }
                return !inner.contains { ($0["command"] as? String)?.hasPrefix(prefix) ?? false }
            }
            if entries.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = entries }
        }
        if hooks.isEmpty { json.removeValue(forKey: "hooks") } else { json["hooks"] = hooks }
        try atomicWrite(json: json, to: settingsURL)
    }

    private static func backup(data: Data, suffix: String) throws {
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
        let url = settingsURL.appendingPathExtension("bak.\(suffix).\(stamp)")
        try data.write(to: url)
    }

    private static func atomicWrite(json: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        let tmp = url.deletingLastPathComponent()
            .appendingPathComponent(".tmp.\(UUID().uuidString)")
        try data.write(to: tmp)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    }

    enum InstallError: LocalizedError {
        case bundleResourcesMissing
        var errorDescription: String? {
            switch self {
            case .bundleResourcesMissing:
                return "App bundle is missing hook scripts (Resources/hooks/). Try reinstalling Claude Mascot."
            }
        }
    }
}
