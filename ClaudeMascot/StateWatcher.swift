import Foundation
import os

final class StateWatcher {
    static let log = Logger(subsystem: "app.claude-mascot", category: "watcher")

    private let dirURL: URL
    private let onChange: (State) -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private var lastState: State?
    private var reattachAttempts = 0
    private var stalenessTimer: Timer?

    init(onChange: @escaping (State) -> Void) {
        self.dirURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude-helper/sessions")
        self.onChange = onChange
    }

    func start() {
        ensureDir()
        scan()
        attach()
        // Catches state files that age past the staleness cutoff with no fs
        // events to wake the DispatchSource (e.g. a killed session leaves a
        // "working" file untouched — without this poll the mascot would stay
        // green until the next unrelated fs event).
        stalenessTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.scan()
        }
    }

    deinit {
        stalenessTimer?.invalidate()
        source?.cancel()
    }

    private func ensureDir() {
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
    }

    private func attach() {
        ensureDir()
        fd = open(dirURL.path, O_EVTONLY)
        guard fd >= 0 else {
            Self.log.error("open(\(self.dirURL.path, privacy: .public)) failed: \(errno)")
            scheduleReattach()
            return
        }
        reattachAttempts = 0
        let s = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        s.setEventHandler { [weak self] in
            guard let self else { return }
            // .delete/.rename invalidate the descriptor — re-attach to a fresh dir.
            let events = self.source?.data ?? []
            if events.contains(.delete) || events.contains(.rename) {
                Self.log.info("watched dir went away, re-attaching")
                self.source?.cancel()
                self.source = nil
                self.scheduleReattach()
                return
            }
            self.scan()
        }
        s.setCancelHandler { [fd] in close(fd) }
        s.resume()
        source = s
    }

    private func scheduleReattach() {
        reattachAttempts += 1
        let delay = min(pow(2.0, Double(reattachAttempts)), 30.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.attach()
            self?.scan()
        }
    }

    private func scan() {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: dirURL.path)) ?? []
        // Active turns rewrite the .state file on every PreToolUse/PostToolUse
        // hook, so a file untouched for >5 minutes is almost certainly an orphan
        // from a session that was killed without firing the Stop hook.
        let cutoff = Date().addingTimeInterval(-5 * 60)
        var worst: State = .idle
        var sawAny = false
        var stateFileCount = 0
        for name in names where name.hasSuffix(".state") {
            stateFileCount += 1
            let url = dirURL.appendingPathComponent(name)
            guard
                let attrs = try? fm.attributesOfItem(atPath: url.path),
                let mtime = attrs[.modificationDate] as? Date,
                mtime > cutoff,
                let raw = try? String(contentsOf: url, encoding: .utf8),
                let parsed = State(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines))
            else { continue }
            sawAny = true
            if parsed > worst { worst = parsed }
        }
        let result: State = sawAny ? worst : .idle
        guard result != lastState else { return }
        lastState = result
        Self.log.debug("scan -> \(result.rawValue, privacy: .public) (files=\(stateFileCount))")
        onChange(result)
    }
}
