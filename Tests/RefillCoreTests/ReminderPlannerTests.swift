import Foundation
import Testing
@testable import RefillCore

struct ReminderPlannerTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let settings = RefillSettings()

    func window(_ minutes: Int = 300, used: Double = 70, resetsIn: TimeInterval) -> LimitWindow {
        LimitWindow(provider: "codex", limitId: "codex", usedPercent: used, windowMinutes: minutes,
                    resetsAt: now.addingTimeInterval(resetsIn))
    }

    /// What Reminders would hold after applying `spec`.
    func stored(_ spec: ReminderSpec, id: String = "r1", completed: Bool = false) -> ManagedReminder {
        ManagedReminder(id: id, key: spec.key, title: spec.title, notes: spec.notes, dueDate: spec.dueDate,
                        alarmDates: spec.alarmDates, isCompleted: completed)
    }

    func spec(_ w: LimitWindow, _ s: RefillSettings? = nil) -> ReminderSpec {
        ReminderPlanner.makeSpec(for: w, settings: s ?? settings, now: now)
    }

    @Test func createsOneReminderPerWindowAlarmingAtReset() {
        let five = window(resetsIn: 3600), week = window(10080, used: 20, resetsIn: 86400 * 3)
        let actions = ReminderPlanner.plan(windows: [five, week], existing: [], settings: settings, now: now)

        guard case .create(let a) = actions.first, case .create(let b) = actions.last else {
            Issue.record("expected two creates, got \(actions)"); return
        }
        #expect(actions.count == 2)
        #expect(a.title == "Codex 5-hour limit resets")
        #expect(a.alarmDates == [five.resetsAt])
        #expect(b.title == "Codex weekly limit resets")
    }

    @Test func providersShareOneListWithoutTouchingEachOther() {
        let codex = window(resetsIn: 3600)
        let claude = LimitWindow(provider: "claude", limitId: "claude", usedPercent: 50, windowMinutes: 300,
                                 resetsAt: now.addingTimeInterval(7200))
        let existing = [stored(spec(codex), id: "codex"), stored(spec(claude), id: "claude")]
        #expect(ReminderPlanner.plan(windows: [codex, claude], existing: existing, settings: settings, now: now).isEmpty)
        #expect(spec(claude).title == "Claude 5-hour limit resets")

        // Turning Claude off removes its pending reminder even though it's no longer fetched; Codex stays.
        var s = settings
        s.disabledProviders = ["claude"]
        #expect(ReminderPlanner.plan(windows: [codex], existing: existing, settings: s, now: now) == [.delete(id: "claude")])
    }

    @Test func settingsSavedByOlderVersionsStillLoad() throws {
        let v1 = #"{"leadMinutes":15,"earlyHeadsUpMinutes":0,"minUsedPercent":50,"disabledWindowMinutes":[10080],"listName":"Mine","completeAfterMinutes":30}"#
        let s = try JSONDecoder().decode(RefillSettings.self, from: Data(v1.utf8))
        #expect(s.leadMinutes == 15 && s.listName == "Mine" && s.disabledWindowMinutes == [10080])
        #expect(s.disabledProviders.isEmpty)
    }

    @Test func unchangedStateIsANoOp() {
        let w = window(resetsIn: 3600)
        #expect(ReminderPlanner.plan(windows: [w], existing: [stored(spec(w))], settings: settings, now: now).isEmpty)
    }

    @Test func movedResetUpdatesTheSameReminderInsteadOfDuplicating() {
        let before = window(resetsIn: 3600)
        let earlyReset = window(used: 5, resetsIn: 600)   // e.g. provider reset limits early
        let actions = ReminderPlanner.plan(windows: [earlyReset], existing: [stored(spec(before))], settings: settings, now: now)
        #expect(actions == [.update(id: "r1", spec(earlyReset))])
    }

    @Test func rolledOverWindowLeavesRingingReminderAndSchedulesNext() {
        let old = window(resetsIn: -300)          // reset 5 min ago, still within the completion grace period
        let next = window(used: 3, resetsIn: 5 * 3600)
        let actions = ReminderPlanner.plan(windows: [next], existing: [stored(spec(old), id: "old")], settings: settings, now: now)
        #expect(actions == [.create(spec(next))])
    }

    @Test func passedRemindersAreCompletedAfterGrace() {
        let old = window(resetsIn: -Double(settings.completeAfterMinutes * 60) - 1)
        let actions = ReminderPlanner.plan(windows: [old], existing: [stored(spec(old), id: "old")], settings: settings, now: now)
        #expect(actions == [.complete(id: "old")])
    }

    @Test func reminderTheUserTickedOffIsNotRecreated() {
        let w = window(resetsIn: 3600)
        let actions = ReminderPlanner.plan(windows: [w], existing: [stored(spec(w), completed: true)], settings: settings, now: now)
        #expect(actions.isEmpty)
    }

    @Test func belowThresholdOrDisabledWindowsRemovePendingReminders() {
        var s = settings
        s.minUsedPercent = 50
        let light = window(used: 10, resetsIn: 3600)
        #expect(ReminderPlanner.plan(windows: [light], existing: [stored(spec(light))], settings: s, now: now) == [.delete(id: "r1")])

        var off = settings
        off.disabledWindowMinutes = [300]
        let w = window(resetsIn: 3600)
        #expect(ReminderPlanner.plan(windows: [w], existing: [], settings: off, now: now).isEmpty)
    }

    @Test func duplicateOpenRemindersCollapseToOne() {
        let w = window(resetsIn: 3600)
        let existing = [stored(spec(w), id: "a"), stored(spec(w), id: "b")]
        let actions = ReminderPlanner.plan(windows: [w], existing: existing, settings: settings, now: now)
        #expect(actions.count == 1)
        guard case .delete = actions.first else { Issue.record("expected delete, got \(actions)"); return }
    }

    @Test func leadAndHeadsUpAlarmsSkipTimesAlreadyPast() {
        var s = settings
        s.leadMinutes = 5
        s.earlyHeadsUpMinutes = 60
        let soon = window(resetsIn: 20 * 60)   // heads-up time (60 min before) is already past
        #expect(spec(soon, s).alarmDates == [soon.resetsAt.addingTimeInterval(-300)])

        let later = window(resetsIn: 3 * 3600)
        #expect(spec(later, s).alarmDates == [later.resetsAt.addingTimeInterval(-3600), later.resetsAt.addingTimeInterval(-300)])
    }

    @Test func hittingTheLimitMarksReminderUrgent() {
        let blocked = spec(window(used: 100, resetsIn: 3600))
        #expect(blocked.highPriority)
        #expect(blocked.title == "Codex unblocked: 5-hour limit resets")
    }
}
