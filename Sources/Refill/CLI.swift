import Foundation
import RefillCore
import ServiceManagement

enum CLI {
    static let help = """
    Refill \(RefillInfo.version): Codex usage limits → Apple Reminders

    USAGE
      Refill              launch the menu bar app
      Refill status       print your current Codex limits
      Refill status --json
      Refill sync         update reminders once, then exit
      Refill doctor       diagnose setup and show the app's last sync
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
        case "unregister-login": try? SMAppService.mainApp.unregister()   // used by the uninstaller
        case "--version", "-v": print(RefillInfo.version)
        case "--help", "-h", "help": print(help)
        default:
            FileHandle.standardError.write("Unknown command: \(cmd)\n\n\(help)\n".data(using: .utf8)!)
            exit(2)
        }
        return true
    }

    static func status(json: Bool) {
        let (snap, liveError) = UsageFetcher.fetch(codexPathOverride: savedCodexPath, useLive: true)
        if json {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            if let snap, let d = try? enc.encode(snap) { print(String(decoding: d, as: UTF8.self)) } else { print("null") }
            return
        }
        guard let snap else {
            print("No Codex usage found. \(liveError ?? "")")
            exit(1)
        }
        let src = snap.source == .live ? "live" : "session logs (live failed: \(liveError ?? "off"))"
        print("Codex \(snap.planType ?? "") · source: \(src)")
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        for w in snap.windows.sorted(by: { $0.windowMinutes < $1.windowMinutes }) {
            let bar = String(repeating: "█", count: Int(min(100, w.usedPercent) / 5))
                .padding(toLength: 20, withPad: "░", startingAt: 0)
            let when = w.resetsAt > Date() ? "resets \(f.string(from: w.resetsAt))" : "already reset"
            print("  \(w.providerLabel) \(w.windowLabel.padding(toLength: 7, withPad: " ", startingAt: 0)) \(bar) \(String(format: "%3.0f", w.usedPercent))%  \(when)")
        }
    }

    static func doctor() {
        let codex = CodexLocator.findCodex(override: savedCodexPath)
        print("codex CLI:      \(codex ?? "NOT FOUND (install Codex or set its path in Settings)")")
        print("codex home:     \(CodexLocator.codexHome.path)")
        print("session logs:   \(CodexSessionLogSource.latest().map { "latest event \($0.observedAt)" } ?? "none in the last 8 days")")
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
            print("Windows: \(r.snapshot?.windows.count ?? 0) · changes: \(r.changes) · open reminders: \(r.reminders.count)")
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
