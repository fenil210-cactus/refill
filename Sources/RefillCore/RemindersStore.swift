import EventKit
import Foundation

public enum RemindersAccess: Equatable { case granted, denied, notDetermined }

/// Thin EventKit wrapper. Every reminder Refill writes carries a `[refill:<key>]` tag in its
/// notes (plus a refill:// URL), so it's found again after restarts or reinstalls without local state.
public final class RemindersStore {
    public let store = EKEventStore()
    static let tagPrefix = "[refill:"

    public init() {}

    public static var access: RemindersAccess {
        let s = EKEventStore.authorizationStatus(for: .reminder)
        switch s {
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        default:
            if #available(macOS 14.0, *) { return s == .fullAccess ? .granted : .denied }
            return .granted
        }
    }

    public func requestAccess() async -> Bool {
        do {
            if #available(macOS 14.0, *) { return try await store.requestFullAccessToReminders() }
            return try await store.requestAccess(to: .reminder)
        } catch { return false }
    }

    /// Finds the list by name, creating it in the default reminders account (iCloud if enabled).
    public func list(named name: String) throws -> EKCalendar {
        if let c = store.calendars(for: .reminder).first(where: { $0.title == name }) { return c }
        let cal = EKCalendar(for: .reminder, eventStore: store)
        cal.title = name
        cal.cgColor = CGColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1)
        let sources = store.sources
        cal.source = store.defaultCalendarForNewReminders()?.source
            ?? sources.first(where: { $0.sourceType == .calDAV })
            ?? sources.first(where: { $0.sourceType == .local })
        try store.saveCalendar(cal, commit: true)
        return cal
    }

    public func managedReminders(in cal: EKCalendar) async -> [ManagedReminder] {
        let predicate = store.predicateForReminders(in: [cal])
        let items: [EKReminder] = await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { cont.resume(returning: $0 ?? []) }
        }
        return items.compactMap { r in
            guard let key = Self.key(of: r) else { return nil }
            return ManagedReminder(id: r.calendarItemIdentifier, key: key, title: r.title ?? "",
                                   notes: Self.stripTag(r.notes), dueDate: r.dueDateComponents?.date,
                                   alarmDates: (r.alarms ?? []).compactMap(\.absoluteDate),
                                   isCompleted: r.isCompleted, completionDate: r.completionDate)
        }
    }

    @discardableResult
    public func apply(_ actions: [ReminderAction], in cal: EKCalendar) throws -> Int {
        var changed = 0
        for action in actions {
            switch action {
            case .create(let spec):
                let r = EKReminder(eventStore: store)
                r.calendar = cal
                fill(r, with: spec)
                try store.save(r, commit: false)
            case .update(let id, let spec):
                guard let r = store.calendarItem(withIdentifier: id) as? EKReminder else { continue }
                fill(r, with: spec)
                try store.save(r, commit: false)
            case .complete(let id):
                guard let r = store.calendarItem(withIdentifier: id) as? EKReminder else { continue }
                r.isCompleted = true
                try store.save(r, commit: false)
            case .delete(let id):
                guard let r = store.calendarItem(withIdentifier: id) as? EKReminder else { continue }
                try store.remove(r, commit: false)
            }
            changed += 1
        }
        if changed > 0 { try store.commit() }
        return changed
    }

    /// Removes Refill's own completed reminders older than `days`, so the list never piles up.
    public func pruneCompleted(in cal: EKCalendar, olderThan days: Double = 7) async {
        let cutoff = Date().addingTimeInterval(-days * 86400)
        let predicate = store.predicateForCompletedReminders(withCompletionDateStarting: nil, ending: cutoff, calendars: [cal])
        let items: [EKReminder] = await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { cont.resume(returning: $0 ?? []) }
        }
        var removed = false
        for r in items where Self.key(of: r) != nil {
            try? store.remove(r, commit: false); removed = true
        }
        if removed { try? store.commit() }
    }

    func fill(_ r: EKReminder, with spec: ReminderSpec) {
        r.title = spec.title
        r.notes = spec.notes + "\n\(Self.tagPrefix)\(spec.key)]"
        r.url = URL(string: "refill://\(spec.key)")
        r.timeZone = TimeZone.current
        r.dueDateComponents = Calendar.current.dateComponents(
            [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second], from: spec.dueDate)
        r.alarms?.forEach { r.removeAlarm($0) }
        for d in spec.alarmDates { r.addAlarm(EKAlarm(absoluteDate: d)) }
        r.priority = spec.highPriority ? 1 : 0
    }

    static func key(of r: EKReminder) -> String? {
        if let notes = r.notes, let range = notes.range(of: tagPrefix) {
            let rest = notes[range.upperBound...]
            if let end = rest.firstIndex(of: "]") { return String(rest[..<end]) }
        }
        if let u = r.url, u.scheme == "refill" {
            return u.absoluteString.replacingOccurrences(of: "refill://", with: "")
        }
        return nil
    }

    static func stripTag(_ notes: String?) -> String? {
        guard let notes, let range = notes.range(of: "\n" + tagPrefix) else { return notes }
        return String(notes[..<range.lowerBound])
    }
}
