import Foundation

/// A reminder Refill owns, as read back from Reminders.
public struct ManagedReminder: Equatable, Sendable {
    public var id: String
    public var key: String
    public var title: String
    public var notes: String?
    public var dueDate: Date?
    public var alarmDates: [Date]
    public var isCompleted: Bool
    public var completionDate: Date?

    public init(id: String, key: String, title: String, notes: String?, dueDate: Date?,
                alarmDates: [Date], isCompleted: Bool, completionDate: Date? = nil) {
        self.id = id; self.key = key; self.title = title; self.notes = notes
        self.dueDate = dueDate; self.alarmDates = alarmDates
        self.isCompleted = isCompleted; self.completionDate = completionDate
    }
}

public struct ReminderSpec: Equatable, Sendable {
    public var key: String
    public var title: String
    public var notes: String
    public var dueDate: Date
    public var alarmDates: [Date]
    public var highPriority: Bool
}

public enum ReminderAction: Equatable, Sendable {
    case create(ReminderSpec)
    case update(id: String, ReminderSpec)
    case complete(id: String)
    case delete(id: String)
}

/// Pure decision logic: given what the provider says now and what's in Reminders,
/// return the minimal set of changes. Keeps exactly one open reminder per window and
/// follows the reset time wherever it moves.
public enum ReminderPlanner {
    static let sameTimeTolerance: TimeInterval = 90

    public static func plan(windows: [LimitWindow], existing: [ManagedReminder],
                            settings: RefillSettings, now: Date = Date()) -> [ReminderAction] {
        var actions: [ReminderAction] = []
        let grace = TimeInterval(settings.completeAfterMinutes * 60)
        let activeKeys = Set(windows.map(\.key))

        // 1. Retire open reminders whose reset already happened (any key, incl. windows no longer reported).
        var open: [String: [ManagedReminder]] = [:]
        for r in existing where !r.isCompleted {
            if let due = r.dueDate, due.addingTimeInterval(grace) <= now {
                actions.append(.complete(id: r.id))
            } else if settings.disabledProviders.contains(provider(ofKey: r.key)) {
                // Provider switched off: drop pending reminders, keep one that is ringing right now.
                if (r.dueDate ?? .distantPast) > now { actions.append(.delete(id: r.id)) }
            } else if let due = r.dueDate, due <= now, !activeKeys.contains(r.key) {
                continue   // just reset; leave visible until grace passes
            } else {
                open[r.key, default: []].append(r)
            }
        }

        for w in windows where !settings.disabledProviders.contains(w.provider) {
            var candidates = (open[w.key] ?? []).sorted { ($0.dueDate ?? .distantPast) > ($1.dueDate ?? .distantPast) }
            let wanted = w.resetsAt > now
                && !settings.disabledWindowMinutes.contains(w.windowMinutes)
                && w.usedPercent >= settings.minUsedPercent

            guard wanted else {
                // Window reset already, is disabled, or below threshold → remove our pending reminders for it,
                // but keep one that is currently ringing (due just passed).
                for r in candidates where (r.dueDate ?? .distantPast) > now {
                    actions.append(.delete(id: r.id))
                }
                continue
            }

            let spec = makeSpec(for: w, settings: settings, now: now)

            // An open reminder whose time already passed belongs to the previous window: let it finish ringing.
            candidates.removeAll { ($0.dueDate ?? .distantPast) <= now && !close($0.dueDate, spec.dueDate) }

            if let keep = candidates.first {
                for dup in candidates.dropFirst() { actions.append(.delete(id: dup.id)) }
                if differs(keep, spec) { actions.append(.update(id: keep.id, spec)) }
                continue
            }

            // User already ticked off the reminder for this exact reset → respect that.
            let dismissed = existing.contains { $0.isCompleted && $0.key == w.key && close($0.dueDate, spec.dueDate) }
            if !dismissed { actions.append(.create(spec)) }
        }
        return actions
    }

    public static func makeSpec(for w: LimitWindow, settings: RefillSettings, now: Date) -> ReminderSpec {
        let used = Int(w.usedPercent.rounded())
        let blocked = w.usedPercent >= 100
        let label = w.windowLabel
        let title = blocked
            ? "\(w.providerLabel) unblocked: \(label) limit resets"
            : "\(w.providerLabel) \(label) limit resets"

        var alarms: [Date] = []
        for lead in [settings.earlyHeadsUpMinutes, settings.leadMinutes] where lead >= 0 {
            let d = w.resetsAt.addingTimeInterval(-TimeInterval(lead * 60))
            if d > now, !alarms.contains(d) { alarms.append(d) }
        }
        if alarms.isEmpty { alarms = [w.resetsAt] }
        alarms.sort()

        let time = DateFormatter.localizedString(from: w.resetsAt, dateStyle: .medium, timeStyle: .short)
        let notes = """
        \(used)% of your \(label) window used. Fresh limit at \(time).
        Kept up to date by Refill. Don't edit; it moves if the reset time changes.
        """
        return ReminderSpec(key: w.key, title: title, notes: notes, dueDate: w.resetsAt,
                            alarmDates: alarms, highPriority: blocked)
    }

    /// Keys are "provider/limitId/windowMinutes" (see `LimitWindow.key`).
    static func provider(ofKey key: String) -> String {
        String(key.prefix { $0 != "/" })
    }

    static func close(_ a: Date?, _ b: Date?) -> Bool {
        guard let a, let b else { return false }
        return abs(a.timeIntervalSince(b)) <= sameTimeTolerance
    }

    static func differs(_ r: ManagedReminder, _ s: ReminderSpec) -> Bool {
        guard close(r.dueDate, s.dueDate), r.title == s.title, r.notes == s.notes,
              r.alarmDates.count == s.alarmDates.count else { return true }
        return zip(r.alarmDates.sorted(), s.alarmDates).contains { !close($0, $1) }
    }
}
