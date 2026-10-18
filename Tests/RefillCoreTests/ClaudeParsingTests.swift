import Foundation
import Testing
@testable import RefillCore

struct ClaudeParsingTests {
    func json(_ s: String) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(s.utf8)) as? [String: Any])
    }

    func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func sh(_ command: String) throws -> String {
        let proc = Process(), out = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", command]
        proc.standardOutput = out
        proc.standardError = FileHandle.nullDevice
        try proc.run(); proc.waitUntilExit()
        return String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }

    @Test func connectUpgradesTheEarlierCommandFormatKeepingTheWrappedCommand() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let settings = dir.appendingPathComponent("settings.json")
        let old = ["statusLine": ["type": "command", "command": "'/Old/Refill' claude-statusline --then 'npx ccstatusline'"]]
        try JSONSerialization.data(withJSONObject: old).write(to: settings)

        try ClaudeStatusLine.connect(refillPath: "/New/Refill", settingsURL: settings, backupURL: dir.appendingPathComponent("b.json"))
        let cmd = try #require((try ClaudeStatusLine.readSettings(settings)["statusLine"] as? [String: Any])?["command"] as? String)
        #expect(cmd == ClaudeStatusLine.command(refillPath: "/New/Refill", wrapping: "npx ccstatusline"))
        #expect(ClaudeStatusLine.wrappedCommand(in: cmd) == "npx ccstatusline")
    }

    @Test func statusLineInputBecomesFiveHourAndWeeklyWindows() throws {
        // Status line input shape documented by Claude Code (rate_limits for Pro/Max subscribers).
        let input = try json("""
        {"session_id":"abc","cwd":"/tmp","model":{"id":"claude-opus-5-5","display_name":"Opus"},
         "rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1792333969},
                        "seven_day":{"used_percentage":41,"resets_at":1792874601}}}
        """)
        let snap = try #require(ClaudeParsing.parseStatusLineInput(input))

        #expect(snap.source == .statusLine)
        #expect(snap.windows.map(\.key) == ["claude/claude/300", "claude/claude/10080"])
        #expect(snap.windows.map(\.usedPercent) == [23.5, 41])
        #expect(snap.windows[0].resetsAt == Date(timeIntervalSince1970: 1792333969))
        #expect(snap.windows[1].providerLabel == "Claude")
    }

    @Test func isoResetsPerModelWeeklyAndUnusableWindows() throws {
        // OAuth usage API shape: `utilization` and ISO 8601 `resets_at`; null and unknown windows are skipped.
        let rl = try json("""
        {"five_hour":{"utilization":100,"resets_at":"2026-10-18T20:00:00.123Z"},
         "seven_day":null,
         "seven_day_opus":{"utilization":12,"resets_at":"2026-10-24T09:00:00Z"},
         "seven_day_oauth_apps":{"utilization":3,"resets_at":"2026-10-24T09:00:00Z"},
         "seven_day_sonnet":{"utilization":5,"resets_at":null}}
        """)
        let snap = try #require(ClaudeParsing.parseRateLimits(rl, observedAt: Date()))

        #expect(snap.windows.map(\.key) == ["claude/claude/300", "claude/opus/10080"])
        #expect(snap.windows[0].resetsAt == CodexParsing.parseISO("2026-10-18T20:00:00.123Z"))
        #expect(snap.windows[1].providerLabel == "Claude Opus")
        #expect(ClaudeParsing.parseRateLimits(["five_hour": NSNull()], observedAt: Date()) == nil)
    }

    @Test func statusLineHookSavesOnlyLimitsAndFeedsPreviousStatusLine() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = dir.appendingPathComponent("rate-limits.json")
        let piped = dir.appendingPathComponent("piped.json")
        let input = Data("""
        {"cwd":"/secret/project","transcript_path":"/x.jsonl",
         "rate_limits":{"five_hour":{"used_percentage":80,"resets_at":1792333969}}}
        """.utf8)

        let status = ClaudeStatusLine.handle(input: input, then: "cat > '\(piped.path)'; exit 3", cacheURL: cache)

        #expect(status == 3)
        #expect(try Data(contentsOf: piped) == input)   // previous status line gets the untouched input
        let saved = try String(contentsOf: cache, encoding: .utf8)
        #expect(!saved.contains("/secret/project"))
        let snap = try #require(ClaudeStatusLine.latest(cacheURL: cache))
        #expect(snap.windows.map(\.key) == ["claude/claude/300"])
        #expect(snap.windows.first?.usedPercent == 80)
    }

    @Test func connectWrapsExistingStatusLineAndDisconnectRestoresIt() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let settings = dir.appendingPathComponent("settings.json")
        let backup = dir.appendingPathComponent("backup.json")
        let previous = #"bash -c 'echo "it'\''s fine"' | tr a-z A-Z"#
        let original: [String: Any] = ["theme": "dark",
                                       "statusLine": ["type": "command", "command": previous, "padding": 1]]
        try JSONSerialization.data(withJSONObject: original).write(to: settings)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settings.path)

        // A stand-in for the Refill binary that echoes its arguments, at a path that needs quoting.
        let app = dir.appendingPathComponent("Refill's.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        let fakeRefill = app.appendingPathComponent("Refill")
        try "#!/bin/sh\nprintf '%s\\n' \"$@\"\n".write(to: fakeRefill, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeRefill.path)

        try ClaudeStatusLine.connect(refillPath: fakeRefill.path, settingsURL: settings, backupURL: backup)
        let connected = try ClaudeStatusLine.readSettings(settings)
        let cmd = try #require((connected["statusLine"] as? [String: Any])?["command"] as? String)
        #expect(ClaudeStatusLine.isRefillCommand(cmd))
        #expect(connected["theme"] as? String == "dark")

        // The shell hands Refill the previous command as one intact `--then` argument, and only once.
        #expect(try sh(cmd) == "claude-statusline\n--then\n\(previous)\n")
        // Refill deleted without the uninstaller: Claude Code still shows the previous status line.
        try FileManager.default.removeItem(at: fakeRefill)
        #expect(try sh(cmd) == "IT'S FINE\n")

        try ClaudeStatusLine.disconnect(settingsURL: settings, backupURL: backup)
        let restored = try ClaudeStatusLine.readSettings(settings)
        #expect(restored as NSDictionary == original as NSDictionary)
        // settings.json can hold env secrets: rewriting it must not make it world-readable.
        let mode = try FileManager.default.attributesOfItem(atPath: settings.path)[.posixPermissions] as? Int
        #expect(mode == 0o600)
    }
}
