import Foundation

final class StateWatcher {
    private let dirURL: URL
    private let onChange: (State) -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1

    init(onChange: @escaping (State) -> Void) {
        self.dirURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude-helper/sessions")
        self.onChange = onChange
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
    }

    func start() {
        scan()
        attach()
    }

    deinit {
        source?.cancel()
    }

    private func attach() {
        fd = open(dirURL.path, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("StateWatcher: open(%@) failed: %d", dirURL.path, errno)
            return
        }
        let s = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        s.setEventHandler { [weak self] in self?.scan() }
        s.setCancelHandler { [fd] in close(fd) }
        s.resume()
        source = s
    }

    private func scan() {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: dirURL.path)) ?? []
        let cutoff = Date().addingTimeInterval(-12 * 3600)
        var worst: State = .idle
        var sawAny = false
        for name in names where name.hasSuffix(".state") {
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
        onChange(sawAny ? worst : .idle)
    }
}
