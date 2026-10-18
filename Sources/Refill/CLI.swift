import Foundation
import RefillCore
import ServiceManagement

enum CLI {
    static let help = """
    Refill \(RefillInfo.version): Codex and Claude Code usage limits → Apple Reminders

    USAGE
      Refill              launch the menu bar app
      Refill status       print your current Codex and Claude limits
      Refill status --json
      Refill sync         update reminders once, then exit
      Refill doctor       diagnose setup and show the app's last sync
      Refill claude-statusline [--then <command>]
                          Claude Code status line hook: saves rate_limits from stdin,
                          then runs <command> (your previous status line)
      Refill claude-connect | claude-disconnect
                          point Claude Code's status line at Refill, or restore the previous one
      Refill --version
    """

    /// Returns true if a CLI command was handled (the process should exit).
    static func run(_ args: [String]) -> Bool {
        // macOS passes -psn_… / -NSDocumentRevisionsDebugMode when launched from Finder/Xcode.
        let args = args.filter { !$0.hasPrefix("-psn") && !$0.hasPrefix("-NS") && !$0.hasPrefix("-Apple") }
        guard let cmd = args.first else { return false }
        switch cmd {
        case "status": status(json: args.contains("--json"))
        case "sync": sync()
        case "doctor": doctor()
        case "claude-connect", "claude-disconnect":
            do {
                if cmd == "claude-connect" {
                    guard let exe = Bundle.main.executableURL?.resolvingSymlinksInPath().path else { exit(1) }
                    try ClaudeStatusLine.connect(refillPath: exe)
                } else {
                    try ClaudeStatusLine.disconnect()
                }
                print("Claude Code status line: \(ClaudeStatusLine.isConnected ? "connected" : "not connected") (\(ClaudeStatusLine.settingsURL.path))")
            } catch {
                FileHandle.standardError.write("\(error.localizedDescription)\n".data(using: .utf8)!)
                exit(1)
            }
        case "claude-statusline":
            let then = args.firstIndex(of: "--then").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
            exit(ClaudeStatusLine.handle(input: FileHandle.standardInput.readDataToEndOfFile(), then: then))
        case "unregister-login": try? SMAppService.mainApp.unregister()   // used by the uninstaller
        case "debug-snapshot": MainActor.assumeIsolated { Snapshot.run(args) }   // dev aid: render the popover to PNG
        case "--version", "-v": print(RefillInfo.version)
        case "--help", "-h", "help": print(help)
        default:
            FileHandle.standardError.write("Unknown command: \(cmd)\n\n\(help)\n".data(using: .utf8)!)
            exit(2)
        }
        return true
    }

    static func status(json: Bool) {
        let providers = Provider.allCases.filter { !savedSettings.disabledProviders.contains($0.rawValue) }
        let results = providers.map { p in (p, UsageFetcher.fetch(p, codexPathOverride: savedCodexPath, useLive: true)) }
        if json {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            let snaps = Dictionary(uniqueKeysWithValues: results.compactMap { p, r in r.0.map { (p.rawValue, $0) } })
            if let d = try? enc.encode(snaps) { print(String(decoding: d, as: UTF8.self)) } else { print("{}") }
            return
        }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        var found = false
        for (p, (snap, error)) in results {
            guard let snap else {
                print("\(p.displayName) · no usage found. \(error ?? "")")
                continue
            }
            found = true
            let src: String
            switch snap.source {
            case .live: src = "live"
            case .sessionLog: src = "session logs (live failed: \(error ?? "off"))"
            case .statusLine: src = "Claude Code status line, \(f.string(from: snap.observedAt))"
            }
            print("\(p.displayName) \(snap.planType ?? "") · source: \(src)")
            for w in snap.windows.sorted(by: { $0.windowMinutes < $1.windowMinutes }) {
                let bar = String(repeating: "█", count: Int(min(100, w.usedPercent) / 5))
                    .padding(toLength: 20, withPad: "░", startingAt: 0)
                let when = w.resetsAt > Date() ? "resets \(f.string(from: w.resetsAt))" : "already reset"
                print("  \(w.providerLabel) \(w.windowLabel.padding(toLength: 7, withPad: " ", startingAt: 0)) \(bar) \(String(format: "%3.0f", w.usedPercent))%  \(when)")
            }
        }
        if !found { exit(1) }
    }

    static func doctor() {
        let codex = CodexLocator.findCodex(override: savedCodexPath)
        print("codex CLI:      \(codex ?? "NOT FOUND (install Codex or set its path in Settings)")")
        print("codex home:     \(CodexLocator.codexHome.path)")
        print("session logs:   \(CodexSessionLogSource.latest().map { "latest event \($0.observedAt)" } ?? "none in the last 8 days")")
        print("claude config:  \(ClaudeStatusLine.settingsURL.path) · status line \(ClaudeStatusLine.isConnected ? "connected" : "NOT connected (Settings › Read Claude Code limits)")")
        print("claude limits:  \(ClaudeStatusLine.latest().map { "last seen \($0.observedAt)" } ?? "none yet (\(ClaudeStatusLine.cacheURL.path))")")
        guard let data = try? Data(contentsOf: SyncReport.url) else {
            print("app sync:       no report yet (is Refill running? open ~/Applications/Refill.app)")
            return
        }
        print("app report:     \(SyncReport.url.path)")
        print(String(decoding: data, as: UTF8.self))
    }

    static func sync() {
        let sem = DispatchSemaphore(value: 0)
        Task {
            let r = await SyncEngine().sync(settings: savedSettings, codexPathOverride: savedCodexPath, useLive: true)
            if let e = r.reminderError { print("Reminders: \(e)") }
            for (p, e) in r.errors.sorted(by: { $0.key < $1.key }) where r.snapshots[p] == nil { print("\(p): \(e)") }
            print("Windows: \(r.windows.count) · changes: \(r.changes) · open reminders: \(r.reminders.count)")
            sem.signal()
        }
        sem.wait()
    }

    /// Same store as the app when run from inside Refill.app; the app's domain when run from a dev build.
    static var defaults: UserDefaults {
        Bundle.main.bundleIdentifier == RefillInfo.bundleId ? .standard : (UserDefaults(suiteName: RefillInfo.bundleId) ?? .standard)
    }
    static var savedSettings: RefillSettings {
        guard let d = defaults.data(forKey: "settings"), let s = try? JSONDecoder().decode(RefillSettings.self, from: d) else {
            return RefillSettings()
        }
        return s
    }
    static var savedCodexPath: String? {
        let p = defaults.string(forKey: "codexPath") ?? ""
        return p.isEmpty ? nil : p
    }
}
