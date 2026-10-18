import Foundation

public enum CodexError: Error, LocalizedError {
    case codexNotFound
    case appServer(String)
    case timeout
    case noData

    public var errorDescription: String? {
        switch self {
        case .codexNotFound: return "Couldn't find the `codex` CLI. Install it or set its path in Settings."
        case .appServer(let m): return "codex app-server: \(m)"
        case .timeout: return "codex app-server didn't answer in time."
        case .noData: return "No Codex usage found yet. Send one message in Codex and it will appear."
        }
    }
}

public enum CodexLocator {
    public static var codexHome: URL {
        if let env = ProcessInfo.processInfo.environment["CODEX_HOME"], !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    }

    /// Directories GUI apps don't get on PATH but where `codex` (and `node`, for npm installs) usually live.
    public static var extraSearchDirs: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["/opt/homebrew/bin", "/usr/local/bin", "\(home)/.local/bin", "\(home)/.npm-global/bin",
                "\(home)/.bun/bin", "\(home)/.volta/bin", "\(home)/.cargo/bin", "/usr/bin", "/bin",
                "/Applications/Codex.app/Contents/Resources"]
    }

    /// Finds the codex executable: explicit override → PATH + common dirs → login shell lookup.
    public static func findCodex(override: String? = nil) -> String? {
        let fm = FileManager.default
        if let o = override.map({ ($0 as NSString).expandingTildeInPath }), !o.isEmpty {
            return fm.isExecutableFile(atPath: o) ? o : nil
        }
        let pathDirs = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        for dir in pathDirs + extraSearchDirs {
            let p = (dir as NSString).appendingPathComponent("codex")
            if fm.isExecutableFile(atPath: p) { return p }
        }
        // nvm/asdf/fnm installs are only visible to a login shell.
        if let p = try? runShell("command -v codex"), fm.isExecutableFile(atPath: p) { return p }
        return nil
    }

    static func runShell(_ cmd: String) throws -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-lc", cmd]
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = FileHandle.nullDevice
        try proc.run()
        proc.waitUntilExit()
        let s = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return s.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n").last ?? ""
    }

    /// PATH for child processes, so an npm-installed `codex` can find `node`.
    static func childEnvironment(codexPath: String) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let dirs = [(codexPath as NSString).deletingLastPathComponent] + extraSearchDirs
            + (env["PATH"] ?? "").split(separator: ":").map(String.init)
        var seen = Set<String>()
        env["PATH"] = dirs.filter { seen.insert($0).inserted }.joined(separator: ":")
        return env
    }
}

/// Live limits via the Codex app-server JSON-RPC protocol (the same call the Codex TUI uses).
/// Refill never reads auth tokens itself; Codex handles auth and refresh.
public enum CodexAppServerSource {
    public static func fetch(codexPath: String, timeout: TimeInterval = 25) throws -> UsageSnapshot {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: codexPath)
        proc.arguments = ["app-server"]
        proc.environment = CodexLocator.childEnvironment(codexPath: codexPath)
        let stdin = Pipe(), stdout = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = FileHandle.nullDevice

        let lock = NSLock()
        var buffer = Data()
        var response: [String: Any]?
        let done = DispatchSemaphore(value: 0)

        stdout.fileHandleForReading.readabilityHandler = { h in
            let chunk = h.availableData
            lock.lock(); defer { lock.unlock() }
            if chunk.isEmpty { if response == nil { done.signal() }; h.readabilityHandler = nil; return }
            buffer.append(chunk)
            while let nl = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<nl]
                buffer.removeSubrange(buffer.startIndex...nl)
                guard response == nil,
                      let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      (obj["id"] as? NSNumber)?.intValue == 2 else { continue }
                response = obj
                done.signal()
            }
        }

        try proc.run()
        defer {
            stdout.fileHandleForReading.readabilityHandler = nil
            try? stdin.fileHandleForWriting.close()
            if proc.isRunning { proc.terminate() }
        }
        let messages: [[String: Any]] = [
            ["jsonrpc": "2.0", "id": 1, "method": "initialize",
             "params": ["clientInfo": ["name": "refill", "title": "Refill", "version": RefillInfo.version]]],
            ["jsonrpc": "2.0", "method": "initialized"],
            ["jsonrpc": "2.0", "id": 2, "method": "account/rateLimits/read"],
        ]
        for m in messages {
            var d = try JSONSerialization.data(withJSONObject: m)
            d.append(0x0A)
            stdin.fileHandleForWriting.write(d)
        }

        guard done.wait(timeout: .now() + timeout) == .success else { throw CodexError.timeout }
        lock.lock(); let resp = response; lock.unlock()
        guard let resp else { throw CodexError.appServer("exited without answering") }
        if let err = resp["error"] as? [String: Any] {
            throw CodexError.appServer((err["message"] as? String) ?? "request failed")
        }
        guard let result = resp["result"] as? [String: Any],
              let snap = CodexParsing.parseAppServerResult(result) else { throw CodexError.noData }
        return snap
    }
}

/// Offline fallback: the newest `token_count` event in Codex's rollout logs.
public enum CodexSessionLogSource {
    public static func latest(codexHome: URL = CodexLocator.codexHome, maxAgeDays: Double = 8) -> UsageSnapshot? {
        let cutoff = Date().addingTimeInterval(-maxAgeDays * 86400)
        var files: [(URL, Date)] = []
        let fm = FileManager.default
        for sub in ["sessions", "archived_sessions"] {
            let root = codexHome.appendingPathComponent(sub)
            guard let e = fm.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey],
                                        options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in e where url.pathExtension == "jsonl" {
                if let m = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   m > cutoff { files.append((url, m)) }
            }
        }
        // Newest files first; the first hit is almost always in the most recent one.
        var best: UsageSnapshot?
        for (url, mtime) in files.sorted(by: { $0.1 > $1.1 }).prefix(12) {
            if let b = best, b.observedAt > mtime { break }
            if let snap = lastSnapshot(in: url), snap.observedAt > (best?.observedAt ?? .distantPast) {
                best = snap
            }
        }
        return best
    }

    /// Reads the file backwards in chunks so multi-hundred-MB logs stay cheap.
    static func lastSnapshot(in url: URL, chunkSize: Int = 256 * 1024, maxBytes: Int = 16 * 1024 * 1024) -> UsageSnapshot? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        guard let size = try? h.seekToEnd(), size > 0 else { return nil }
        var offset = size
        var carry = Data()
        var scanned = 0
        while offset > 0 && scanned < maxBytes {
            let len = UInt64(min(UInt64(chunkSize), offset))
            offset -= len
            try? h.seek(toOffset: offset)
            guard let chunk = try? h.read(upToCount: Int(len)) else { break }
            scanned += chunk.count
            var data = chunk + carry
            // Keep the (possibly partial) first line for the next round.
            if offset > 0, let nl = data.firstIndex(of: 0x0A) {
                carry = data[data.startIndex..<nl]
                data = data[data.index(after: nl)...]
            } else { carry = Data() }
            let text = String(decoding: data, as: UTF8.self)
            for line in text.split(separator: "\n").reversed() {
                if let snap = CodexParsing.parseSessionLogLine(line) { return snap }
            }
        }
        return nil
    }
}

public enum RefillInfo {
    public static let version = "1.0.0"
    public static let bundleId = "com.fenil210.refill"
}
