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

    // Per-state staleness cutoffs.
    //   working:   bumped on every PreToolUse/PostToolUse — but a long-running
    //              tool call (docker build, big test run) can pause hooks for
    //              30+ min, so the cutoff has to comfortably cover the slowest
    //              tool calls we tolerate.
    //   attention: written once when Claude is blocked on a permission prompt;
    //              no further hooks fire until the user responds. The user may
    //              be away for hours — we must NOT time the orange out, or the
    //              mascot becomes useless for its highest-value state. 24h is
    //              effectively immortal in practice; orphan attention files
    //              from killed sessions are rare and harmless (menu can clear).
    private static func cutoff(for state: State) -> Date {
        switch state {
        case .working:   return Date().addingTimeInterval(-30 * 60)
        case .attention: return Date().addingTimeInterval(-24 * 3600)
        case .idle:      return Date.distantPast
        }
    }

    private func scan() {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: dirURL.path)) ?? []
        var worst: State = .idle
        var sawAny = false
        var stateFileCount = 0
        for name in names where name.hasSuffix(".state") {
            stateFileCount += 1
            let url = dirURL.appendingPathComponent(name)
            guard
                let attrs = try? fm.attributesOfItem(atPath: url.path),
                let mtime = attrs[.modificationDate] as? Date,
                let raw = try? String(contentsOf: url, encoding: .utf8),
                let parsed = State(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
                mtime > Self.cutoff(for: parsed)
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
