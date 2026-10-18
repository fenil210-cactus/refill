import Foundation

public struct SyncResult: Sendable {
    public var snapshot: UsageSnapshot?
    public var liveError: String?
    public var reminders: [ManagedReminder] = []
    public var changes: Int = 0
    public var reminderError: String?
    public var finishedAt = Date()
}

public enum UsageFetcher {
    /// Live app-server first (knows about early resets even when you're idle); session logs as fallback.
    /// If the logs are newer than a failed live read, they still win.
    public static func fetch(codexPathOverride: String?, useLive: Bool = true) -> (UsageSnapshot?, String?) {
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
}

/// Last sync outcome, written by the app so `Refill doctor` (and bug reports) can show it.
public struct SyncReport: Codable, Sendable {
    public var finishedAt: Date
    public var source: String?
    public var windows: [LimitWindow]
    public var openReminders: [String: Date]
    public var changes: Int
    public var liveError: String?
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
        source = r.snapshot?.source.rawValue
        windows = r.snapshot?.windows ?? []
        openReminders = Dictionary(r.reminders.map { ($0.key, $0.dueDate ?? .distantPast) }, uniquingKeysWith: { a, _ in a })
        changes = r.changes
        liveError = r.liveError
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
                     known: UsageSnapshot? = nil, writeReminders: Bool = true) async -> SyncResult {
        let (fetched, liveError) = await Task.detached {
            UsageFetcher.fetch(codexPathOverride: codexPathOverride, useLive: useLive)
        }.value
        // Never plan from data older than what we already know (a log read can trail a live read).
        let snapshot = [fetched, known].compactMap { $0 }.max { $0.observedAt < $1.observedAt }
        var result = SyncResult(snapshot: snapshot, liveError: liveError)
        guard writeReminders else { return result }

        if RemindersStore.access == .notDetermined { _ = await reminders.requestAccess() }
        guard RemindersStore.access == .granted else {
            result.reminderError = "Reminders access is off. Enable Refill in System Settings › Privacy & Security › Reminders."
            return result
        }
        do {
            let cal = try reminders.list(named: settings.listName)
            let existing = await reminders.managedReminders(in: cal)
            if let snapshot {
                let actions = ReminderPlanner.plan(windows: snapshot.windows, existing: existing, settings: settings)
                result.changes = try reminders.apply(actions, in: cal)
            }
            await reminders.pruneCompleted(in: cal)
            result.reminders = await reminders.managedReminders(in: cal).filter { !$0.isCompleted }
        } catch {
            result.reminderError = error.localizedDescription
        }
        result.finishedAt = Date()
        return result
    }
}
