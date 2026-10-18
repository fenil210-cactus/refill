import Foundation

public enum ClaudeError: Error, LocalizedError {
    case notConnected
    case noData
    case settings(String)

    public var errorDescription: String? {
        switch self {
        case .notConnected: return "Claude Code isn't connected. Turn on \"Read Claude Code limits\" in Settings."
        case .noData: return "No Claude usage yet. Send one message in Claude Code and it will appear. Claude Code only reports plan limits when logged in with Pro or Max, not an API key."
        case .settings(let m): return "Claude Code settings: \(m)"
        }
    }
}

/// Claude Code hands its rate limits to the status line command on every update (`rate_limits` in the
/// status line JSON). Refill registers itself as that command (`Refill claude-statusline`), saves just the
/// `rate_limits` object, then runs your previous status line unchanged. Refill never reads auth tokens.
public enum ClaudeStatusLine {
    static let subcommand = "claude-statusline"
    static let thenFlag = "--then"

    /// Own folder, so watching it doesn't fire on `last-sync.json` writes.
    public static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Refill/claude", isDirectory: true)
    }
    public static var cacheURL: URL { directory.appendingPathComponent("rate-limits.json") }
    public static var backupURL: URL { directory.appendingPathComponent("statusline-backup.json") }

    public static var claudeHome: URL {
        if let env = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }
    public static var settingsURL: URL { claudeHome.appendingPathComponent("settings.json") }

    // MARK: Reading

    /// Latest saved limits, or nil if Claude Code hasn't reported any yet.
    public static func latest(cacheURL: URL = cacheURL) -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: cacheURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return ClaudeParsing.parseCache(obj)
    }

    /// Handles one status line invocation: saves `rate_limits` from stdin, then prints the wrapped
    /// status line's output (or a compact default). Returns the exit status to use.
    public static func handle(input: Data, then command: String?, cacheURL: URL = cacheURL) -> Int32 {
        let obj = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any]
        if let rl = obj?["rate_limits"] as? [String: Any],
           ClaudeParsing.parseRateLimits(rl, observedAt: Date()) != nil {
            save(rateLimits: rl, to: cacheURL)
        }
        if let command, !command.isEmpty { return run(command, input: input) }
        if let obj, let snap = ClaudeParsing.parseStatusLineInput(obj) {
            print(snap.windows.map { "\($0.shortLabel) \(Int($0.usedPercent.rounded()))%" }.joined(separator: " · "))
        } else if let model = (obj?["model"] as? [String: Any])?["display_name"] as? String {
            print(model)
        }
        return 0
    }

    /// Stores only the limits and when they were seen; never the rest of the session payload.
    static func save(rateLimits: [String: Any], to url: URL) {
        // The status line runs after every message; only touch the file (and wake the app) on a change.
        if let old = try? Data(contentsOf: url),
           let obj = try? JSONSerialization.jsonObject(with: old) as? [String: Any],
           (obj["rate_limits"] as? NSDictionary) == (rateLimits as NSDictionary) { return }
        let payload: [String: Any] = ["observed_at": Date().timeIntervalSince1970, "rate_limits": rateLimits]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    static func run(_ command: String, input: Data) -> Int32 {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", command]
        let stdin = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = FileHandle.standardOutput
        proc.standardError = FileHandle.standardError
        do { try proc.run() } catch { return 127 }
        stdin.fileHandleForWriting.write(input)
        try? stdin.fileHandleForWriting.close()
        proc.waitUntilExit()
        return proc.terminationStatus
    }

    // MARK: Connecting

    static let fallbackMarker = " || {\n"

    /// The status line command Refill installs, wrapping `previous` (if any) so it keeps working:
    ///
    ///     [ -x '/…/Refill' ] && exec '/…/Refill' claude-statusline --then '<previous>' || {
    ///     <previous>
    ///     }
    ///
    /// If Refill.app was deleted without the uninstaller, the previous status line still runs.
    /// `exec` means it never runs twice; the newline-delimited group keeps `;`, `&&` and `#` in it intact.
    public static func command(refillPath: String, wrapping previous: String?) -> String {
        let q = shellQuote(refillPath)
        var cmd = "[ -x \(q) ] && exec \(q) \(subcommand)"
        if let previous, !previous.isEmpty {
            cmd += " \(thenFlag) \(shellQuote(previous))\(fallbackMarker)\(previous)\n}"
        }
        return cmd
    }

    public static func isRefillCommand(_ command: String?) -> Bool {
        command?.contains(" \(subcommand)") ?? false
    }

    public static var isConnected: Bool {
        guard let obj = try? readSettings(settingsURL) else { return false }
        return isRefillCommand((obj["statusLine"] as? [String: Any])?["command"] as? String)
    }

    /// Points Claude Code's status line at Refill, keeping the previous one as `--then`.
    public static func connect(refillPath: String, settingsURL: URL = settingsURL, backupURL: URL = backupURL) throws {
        var obj = try readSettings(settingsURL)
        let previous = obj["statusLine"] as? [String: Any]
        let previousCommand = previous?["command"] as? String
        if var line = previous, let current = previousCommand, isRefillCommand(current) {
            guard !current.hasPrefix("[ -x \(shellQuote(refillPath)) ]") else { return }
            // Refill moved, or an older command format: keep the wrapped command, rewrite the rest.
            line["command"] = command(refillPath: refillPath, wrapping: wrappedCommand(in: current))
            obj["statusLine"] = line
            return try writeSettings(obj, to: settingsURL)
        }
        try FileManager.default.createDirectory(at: backupURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let backup = try JSONSerialization.data(withJSONObject: ["statusLine": (previous as Any?) ?? NSNull()])
        try backup.write(to: backupURL, options: .atomic)
        var line = previous ?? ["type": "command", "padding": 0]
        line["type"] = "command"
        line["command"] = command(refillPath: refillPath, wrapping: previousCommand)
        obj["statusLine"] = line
        try writeSettings(obj, to: settingsURL)
    }

    /// Restores the status line Refill replaced (or removes Refill's if there was none).
    public static func disconnect(settingsURL: URL = settingsURL, backupURL: URL = backupURL) throws {
        var obj = try readSettings(settingsURL)
        guard let current = (obj["statusLine"] as? [String: Any])?["command"] as? String,
              isRefillCommand(current) else { return }
        if let data = try? Data(contentsOf: backupURL),
           let backup = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let line = backup["statusLine"] as? [String: Any] {
            obj["statusLine"] = line
        } else if let wrapped = wrappedCommand(in: current) {
            obj["statusLine"] = ["type": "command", "command": wrapped, "padding": 0]
        } else {
            obj.removeValue(forKey: "statusLine")
        }
        try writeSettings(obj, to: settingsURL)
        try? FileManager.default.removeItem(at: backupURL)
    }

    static func readSettings(_ url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeError.settings("\(url.path) isn't a JSON object; leaving it untouched.")
        }
        return obj
    }

    static func writeSettings(_ obj: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Write through a symlink (dotfile setups) instead of replacing it, and keep the file's mode (often 600).
        let target = url.resolvingSymlinksInPath()
        let mode = (try? FileManager.default.attributesOfItem(atPath: target.path))?[.posixPermissions] ?? NSNumber(value: 0o600)
        try data.write(to: target, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: target.path)
    }

    /// The command after `--then`, unquoted (current format, or the earlier one without a fallback).
    static func wrappedCommand(in command: String) -> String? {
        guard let r = command.range(of: " \(thenFlag) ") else { return nil }
        let rest = command[r.upperBound...]
        let quoted = rest.range(of: fallbackMarker).map { rest[..<$0.lowerBound] } ?? rest
        return shellUnquote(String(quoted))
    }

    /// Claude Code is set up on this Mac (so the app can suggest connecting it).
    public static var isInstalled: Bool { FileManager.default.fileExists(atPath: claudeHome.path) }

    static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    static func shellUnquote(_ s: String) -> String {
        guard s.hasPrefix("'"), s.hasSuffix("'"), s.count >= 2 else { return s }
        return String(s.dropFirst().dropLast()).replacingOccurrences(of: #"'\''"#, with: "'")
    }
}

/// Parsers for Claude Code's `rate_limits` object:
/// `{"five_hour": {"used_percentage": 23.5, "resets_at": 1738425600}, "seven_day": {...}}`.
/// Unknown windows and fields are ignored so new Claude Code versions don't break parsing.
public enum ClaudeParsing {
    /// Window name → (limitId, display name, minutes). The shared 5-hour and weekly limits use limitId "claude".
    static let knownWindows: [String: (id: String, name: String?, minutes: Int)] = [
        "five_hour": ("claude", nil, 300),
        "seven_day": ("claude", nil, 10080),
        "seven_day_opus": ("opus", "Opus", 10080),
        "seven_day_sonnet": ("sonnet", "Sonnet", 10080),
    ]

    public static func parseRateLimits(_ rl: [String: Any], observedAt: Date) -> UsageSnapshot? {
        var windows: [LimitWindow] = []
        for name in knownWindows.keys.sorted() {
            guard let spec = knownWindows[name], let w = rl[name] as? [String: Any],
                  let used = CodexParsing.number(w["used_percentage"] ?? w["utilization"]),
                  let resets = date(w["resets_at"]) else { continue }
            windows.append(LimitWindow(provider: "claude", limitId: spec.id, limitName: spec.name,
                                       usedPercent: used, windowMinutes: spec.minutes, resetsAt: resets))
        }
        guard !windows.isEmpty else { return nil }
        let order = { (w: LimitWindow) in (w.limitId == "claude" ? 0 : 1, w.windowMinutes, w.limitId) }
        windows.sort { order($0) < order($1) }
        return UsageSnapshot(windows: windows, planType: nil, limitReachedType: nil,
                             observedAt: observedAt, source: .statusLine)
    }

    /// The full JSON Claude Code pipes to a status line command.
    public static func parseStatusLineInput(_ obj: [String: Any], now: Date = Date()) -> UsageSnapshot? {
        (obj["rate_limits"] as? [String: Any]).flatMap { parseRateLimits($0, observedAt: now) }
    }

    /// The file `ClaudeStatusLine.save` writes.
    public static func parseCache(_ obj: [String: Any]) -> UsageSnapshot? {
        guard let rl = obj["rate_limits"] as? [String: Any],
              let at = CodexParsing.number(obj["observed_at"]) else { return nil }
        return parseRateLimits(rl, observedAt: Date(timeIntervalSince1970: at))
    }

    /// Epoch seconds (documented), epoch milliseconds, or an ISO 8601 string (OAuth usage API shape).
    static func date(_ any: Any?) -> Date? {
        if let s = any as? String, let d = CodexParsing.parseISO(s) { return d }
        return CodexParsing.number(any).map { Date(timeIntervalSince1970: $0 > 1e11 ? $0 / 1000 : $0) }
    }
}
