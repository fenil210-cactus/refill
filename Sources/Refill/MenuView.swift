import RefillCore
import SwiftUI

let brand = Color(red: 0.06, green: 0.73, blue: 0.51)

struct MenuView: View {
    @ObservedObject var model: AppModel
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if showSettings { SettingsPane(model: model) } else { content }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 330)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.circle.fill").font(.system(size: 22)).foregroundStyle(brand)
            VStack(alignment: .leading, spacing: 0) {
                Text("Refill").font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { showSettings.toggle() } label: {
                Image(systemName: showSettings ? "xmark.circle" : "gearshape")
            }.buttonStyle(.borderless).help(showSettings ? "Back" : "Settings")
        }
    }

    private var subtitle: String {
        guard let snap = model.result?.snapshot else { return "Codex usage limits → Apple Reminders" }
        let plan = snap.planType.map { "\($0.capitalized) plan" } ?? "Codex"
        return "\(plan) · \(snap.source == .live ? "live" : "from session logs")"
    }

    @ViewBuilder private var content: some View {
        if model.result == nil {
            HStack { ProgressView().controlSize(.small); Text("Reading your Codex limits…").foregroundStyle(.secondary) }
        } else if model.windows.isEmpty {
            notice("No Codex usage yet", model.result?.liveError ?? CodexError.noData.localizedDescription, icon: "questionmark.circle")
        } else {
            ForEach(model.windows, id: \.key) { WindowCard(window: $0, reminder: model.reminder(for: $0), now: model.now,
                                                          disabled: model.settings.disabledWindowMinutes.contains($0.windowMinutes)) }
        }
        if let err = model.result?.reminderError {
            notice("Reminders not connected", err, icon: "exclamationmark.triangle.fill") {
                Button("Open Privacy Settings") { model.openPrivacySettings() }.controlSize(.small)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button { model.syncNow() } label: {
                if model.syncing { ProgressView().controlSize(.mini) } else { Image(systemName: "arrow.clockwise") }
            }.buttonStyle(.borderless).help("Sync now")
            Text(syncedText).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Reminders") { model.openReminders() }.controlSize(.small)
            Button("Quit") { NSApp.terminate(nil) }.controlSize(.small)
        }
    }

    private var syncedText: String {
        guard let r = model.result else { return "Syncing…" }
        let ago = Int(model.now.timeIntervalSince(r.finishedAt) / 60)
        return ago < 1 ? "Synced just now" : "Synced \(ago)m ago"
    }

    private func notice(_ title: String, _ body: String, icon: String,
                        @ViewBuilder action: () -> some View = { EmptyView() }) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                action()
            }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.orange.opacity(0.08)))
    }
}

struct WindowCard: View {
    let window: LimitWindow
    let reminder: ManagedReminder?
    let now: Date
    let disabled: Bool

    private var reset: Bool { window.resetsAt <= now }
    private var used: Double { reset ? 0 : min(100, window.usedPercent) }
    private var tint: Color { used >= 100 ? .red : used >= 80 ? .orange : brand }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(window.providerLabel) · \(window.windowLabel.capitalized)").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(used.rounded()))%").font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(tint)
                    .monospacedDigit()
            }
            ProgressView(value: used, total: 100).tint(tint)
            HStack(spacing: 4) {
                Image(systemName: "arrow.counterclockwise").font(.caption2)
                Text(reset ? "Refilled. Next window starts with your next message"
                           : "Resets \(Fmt.resetTime(window.resetsAt, now: now)) · in \(Fmt.countdown(to: window.resetsAt, from: now))")
            }.font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Image(systemName: reminder != nil ? "bell.badge.fill" : "bell.slash").font(.caption2)
                Text(reminderText)
            }.font(.caption).foregroundStyle(reminder != nil ? brand : .secondary)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 11).fill(Color.primary.opacity(0.05)))
    }

    private var reminderText: String {
        if disabled { return "Reminders off for this window" }
        if reset { return "Nothing to remind; you're full" }
        guard let r = reminder, let alarm = r.alarmDates.max() else { return "No reminder yet" }
        let t = DateFormatter(); t.timeStyle = .short
        return "Reminder set for \(t.string(from: alarm))"
    }
}

struct SettingsPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Picker("Notify me", selection: $model.settings.leadMinutes) {
                    Text("At reset").tag(0)
                    Text("5 min before").tag(5)
                    Text("15 min before").tag(15)
                    Text("30 min before").tag(30)
                }
                Picker("Extra heads-up", selection: $model.settings.earlyHeadsUpMinutes) {
                    Text("None").tag(0)
                    Text("30 min before").tag(30)
                    Text("1 hour before").tag(60)
                }
                Picker("Only if I've used", selection: $model.settings.minUsedPercent) {
                    Text("Any amount").tag(0.0)
                    Text("≥ 25%").tag(25.0)
                    Text("≥ 50%").tag(50.0)
                    Text("≥ 80%").tag(80.0)
                }
                Toggle("5-hour window", isOn: binding(300))
                Toggle("Weekly window", isOn: binding(10080))
            }
            Section {
                TextField("Reminders list", text: $model.settings.listName)
                Toggle("Live check via codex app-server", isOn: $model.useLive)
                Picker("Background check", selection: $model.pollMinutes) {
                    Text("Every 5 min").tag(5); Text("Every 10 min").tag(10); Text("Every 30 min").tag(30)
                }
                TextField("codex path (auto)", text: $model.codexPath)
                Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            }
            Text("Refill v\(RefillInfo.version) · reads limits locally, writes only to its own Reminders list.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .controlSize(.small)
        .frame(height: 400)
    }

    private func binding(_ minutes: Int) -> Binding<Bool> {
        Binding(get: { !model.settings.disabledWindowMinutes.contains(minutes) },
                set: { model.toggleWindow(minutes, enabled: $0) })
    }
}
