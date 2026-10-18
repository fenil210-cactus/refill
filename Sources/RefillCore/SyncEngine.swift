import Foundation

public struct SyncResult: Sendable {
    /// Latest usage per provider ("codex", "claude").
    public var snapshots: [String: UsageSnapshot] = [:]
    /// Why a provider's live read failed or found nothing, by provider.
    public var errors: [String: String] = [:]
    public var reminders: [ManagedReminder] = []
    public var changes: Int = 0
    public var reminderError: String?
    public var finishedAt = Date()

    public init(snapshots: [String: UsageSnapshot] = [:], errors: [String: String] = [:]) {
        self.snapshots = snapshots
        self.errors = errors
    }

    public var windows: [LimitWindow] { Provider.allCases.flatMap { snapshots[$0.rawValue]?.windows ?? [] } }
}

public enum UsageFetcher {
    public static func fetch(_ provider: Provider, codexPathOverride: String?, useLive: Bool = true) -> (UsageSnapshot?, String?) {
        switch provider {
        case .codex: return fetchCodex(codexPathOverride: codexPathOverride, useLive: useLive)
        case .claude: return fetchClaude()
        }
    }

    /// Live app-server first (knows about early resets even when you're idle); session logs as fallback.
    /// If the logs are newer than a failed live read, they still win.
    public static func fetchCodex(codexPathOverride: String?, useLive: Bool = true) -> (UsageSnapshot?, String?) {
        var liveError: String?
        if useLive {
            if let path = CodexLocator.findCodex(override: codexPathOverride) {
                do { return (try CodexAppServerSource.fetch(codexPath: path), nil) }
                catch { liveError = error.localizedDescription }
            } else {
                liveError = CodexError.codexNotFound.localizedDescription
            }
        }
        return (CodexSessionLogSource.latest(), liveError)
    }

    /// Whatever Claude Code last handed to its status line; reset times are absolute, so it stays valid when idle.
    public static func fetchClaude() -> (UsageSnapshot?, String?) {
        if let snap = ClaudeStatusLine.latest() { return (snap, nil) }
        let err: ClaudeError = ClaudeStatusLine.isConnected ? .noData : .notConnected
        return (nil, err.localizedDescription)
    }
}

/// Last sync outcome, written by the app so `Refill doctor` (and bug reports) can show it.
public struct SyncReport: Codable, Sendable {
    public var finishedAt: Date
    public var sources: [String: String]
    public var windows: [LimitWindow]
    public var openReminders: [String: Date]
    public var changes: Int
    public var errors: [String: String]
    public var reminderError: String?
    public var remindersAccess: String

    public static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Refill", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("last-sync.json")
    }

    public init(_ r: SyncResult) {
        finishedAt = r.finishedAt
        sources = r.snapshots.mapValues(\.source.rawValue)
        windows = r.windows
        openReminders = Dictionary(r.reminders.map { ($0.key, $0.dueDate ?? .distantPast) }, uniquingKeysWith: { a, _ in a })
        changes = r.changes
        errors = r.errors
        reminderError = r.reminderError
        remindersAccess = "\(RemindersStore.access)"
    }

    public func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        try? enc.encode(self).write(to: Self.url, options: .atomic)
    }
}

public final class SyncEngine {
    public let reminders = RemindersStore()
    public init() {}

    public func sync(settings: RefillSettings, codexPathOverride: String?, useLive: Bool,
                     known: [String: UsageSnapshot] = [:], writeReminders: Bool = true) async -> SyncResult {
        let enabled = Provider.allCases.filter { !settings.disabledProviders.contains($0.rawValue) }
        let fetched = await withTaskGroup(of: (Provider, UsageSnapshot?, String?).self) { group in
            for p in enabled {
                group.addTask {
                    let (snap, err) = UsageFetcher.fetch(p, codexPathOverride: codexPathOverride, useLive: useLive)
                    return (p, snap, err)
                }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }
        var result = SyncResult()
        for (p, snap, err) in fetched {
            // Never plan from data older than what we already know (a log read can trail a live read).
            result.snapshots[p.rawValue] = [snap, known[p.rawValue]].compactMap { $0 }.max { $0.observedAt < $1.observedAt }
            result.errors[p.rawValue] = err
        }
        guard writeReminders else { return result }

        if RemindersStore.access == .notDetermined { _ = await reminders.requestAccess() }
        guard RemindersStore.access == .granted else {
            result.reminderError = "Reminders access is off. Enable Refill in System Settings › Privacy & Security › Reminders."
            return result
        }
        do {
            let cal = try reminders.list(named: settings.listName)
            let existing = await reminders.managedReminders(in: cal)
            // Runs even with no fresh data so expired reminders still complete and disabled providers are cleared.
            let actions = ReminderPlanner.plan(windows: result.windows, existing: existing, settings: settings)
            result.changes = try reminders.apply(actions, in: cal)
            await reminders.pruneCompleted(in: cal)
            result.reminders = await reminders.managedReminders(in: cal).filter { !$0.isCompleted }
        } catch {
            result.reminderError = error.localizedDescription
        }
        result.finishedAt = Date()
        return result
    }
}
