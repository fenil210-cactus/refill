import AppKit
import RefillCore
import SwiftUI

let brand = Color(red: 0.06, green: 0.73, blue: 0.51)

struct MenuView: View {
    @ObservedObject var model: AppModel
    @State private var showSettings: Bool

    init(model: AppModel, showSettings: Bool = false) {
        self.model = model
        _showSettings = State(initialValue: showSettings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            // The popover grows with its content and scrolls only when it would run past the screen.
            ScrollView(.vertical) {
                Group {
                    if showSettings { SettingsPane(model: model) } else { content }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.automatic)
            .frame(maxHeight: Self.maxBodyHeight)
            .fixedSize(horizontal: false, vertical: true)
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
        .animation(.easeInOut(duration: 0.18), value: showSettings)
    }

    /// Screen height minus menu bar, header, footer and a margin.
    static var maxBodyHeight: CGFloat {
        let visible = NSScreen.main?.visibleFrame.height ?? 800
        return max(320, visible - 170)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.circle.fill").font(.system(size: 22)).foregroundStyle(brand)
            VStack(alignment: .leading, spacing: 0) {
                Text(showSettings ? "Settings" : "Refill").font(.headline)
                Text(showSettings ? "Refill v\(RefillInfo.version)" : subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { showSettings.toggle() } label: {
                Image(systemName: showSettings ? "xmark.circle" : "gearshape").font(.system(size: 14))
            }.buttonStyle(.borderless).help(showSettings ? "Done" : "Settings")
        }
    }

    private var subtitle: String {
        let names = model.visibleProviders.map(\.displayName)
        return names.isEmpty ? "Usage limits → Apple Reminders" : names.joined(separator: " + ") + " limits"
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.result == nil {
                HStack { ProgressView().controlSize(.small); Text("Reading your limits…").foregroundStyle(.secondary) }
            } else if model.visibleProviders.isEmpty {
                Notice(title: "Nothing to track yet", message: "Refill follows Codex and Claude Code limits. Use one of them on this Mac, or turn it on in Settings.", icon: "questionmark.circle")
            } else {
                ForEach(model.visibleProviders, id: \.self) { providerSection($0) }
            }
            if let err = model.result?.reminderError {
                Notice(title: "Reminders not connected", message: err, icon: "exclamationmark.triangle.fill") {
                    Button("Open Privacy Settings") { model.openPrivacySettings() }.controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder private func providerSection(_ p: Provider) -> some View {
        let windows = model.windows(for: p)
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: p == .claude ? "Claude Code" : p.displayName, detail: sourceDetail(p))
            if p == .claude && !model.claudeConnected {
                Notice(title: "Connect Claude Code",
                       message: "Refill reads your 5-hour and weekly limits from Claude Code's status line (Pro & Max plans). Your current status line keeps working.",
                       icon: "link", tint: brand) {
                    Button("Connect") { model.setClaudeConnected(true) }.controlSize(.small)
                    if let err = model.claudeConnectError { Text(err).font(.caption).foregroundStyle(.orange) }
                }
            } else if windows.isEmpty {
                Notice(title: "Waiting for \(p == .claude ? "Claude Code" : "Codex")",
                       message: p == .claude
                         ? "Send a message in Claude Code and your limits appear here. Limits are reported on Pro & Max plans."
                         : (model.result?.errors[p.rawValue] ?? CodexError.noData.localizedDescription),
                       icon: "hourglass", tint: .secondary)
            } else {
                ForEach(windows, id: \.key) {
                    WindowCard(window: $0, reminder: model.reminder(for: $0), now: model.now,
                               disabled: model.settings.disabledWindowMinutes.contains($0.windowMinutes))
                }
            }
        }
    }

    private func sourceDetail(_ p: Provider) -> String? {
        guard let snap = model.result?.snapshots[p.rawValue] else { return nil }
        let plan = snap.planType.map { "\($0.capitalized) plan · " } ?? ""
        switch snap.source {
        case .live: return plan + "live"
        case .sessionLog: return plan + "from session logs"
        case .statusLine: return "updated \(Fmt.ago(snap.observedAt, now: model.now))"
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
        return "Synced \(Fmt.ago(r.finishedAt, now: model.now))"
    }
}

struct SectionHeader: View {
    let title: String
    let detail: String?
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).tracking(0.6).foregroundStyle(.secondary)
            Spacer()
            if let detail { Text(detail).font(.caption2).foregroundStyle(.tertiary) }
        }
        .padding(.horizontal, 2)
    }
}

struct Notice<Actions: View>: View {
    let title: String
    let message: String
    let icon: String
    var tint: Color = .orange
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                actions()
            }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(tint.opacity(0.08)))
    }
}

extension Notice where Actions == EmptyView {
    init(title: String, message: String, icon: String, tint: Color = .orange) {
        self.init(title: title, message: message, icon: icon, tint: tint) { EmptyView() }
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
    /// The section header already names the provider; only per-model limits need a prefix.
    private var title: String {
        let w = window.windowLabel.capitalized
        return window.limitId == window.provider ? w : "\(window.limitName ?? window.limitId.capitalized) · \(w)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline.weight(.semibold))
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

// MARK: - Settings

/// Grouped rows like System Settings, laid out by hand so the popover (not a nested Form) owns scrolling.
struct SettingsPane: View {
    @ObservedObject var model: AppModel
    @State private var showAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsGroup("Track") {
                SettingsRow("Codex", detail: "Live via the codex CLI") {
                    Toggle("", isOn: providerBinding(.codex)).labelsHidden()
                }
                SettingsRow("Claude Code", detail: "Via its status line · Pro & Max") {
                    Toggle("", isOn: providerBinding(.claude)).labelsHidden()
                }
                if let err = model.claudeConnectError {
                    Text(err).font(.caption).foregroundStyle(.orange).padding(.horizontal, 10).padding(.bottom, 6)
                }
            }
            SettingsGroup("Windows") {
                SettingsRow("5-hour") { Toggle("", isOn: windowBinding(300)).labelsHidden() }
                SettingsRow("Weekly") { Toggle("", isOn: windowBinding(10080)).labelsHidden() }
            }
            SettingsGroup("Alerts") {
                SettingsRow("Notify me") {
                    Picker("", selection: $model.settings.leadMinutes) {
                        Text("At reset").tag(0); Text("5 min before").tag(5); Text("15 min before").tag(15); Text("30 min before").tag(30)
                    }
                }
                SettingsRow("Extra heads-up") {
                    Picker("", selection: $model.settings.earlyHeadsUpMinutes) {
                        Text("None").tag(0); Text("30 min before").tag(30); Text("1 hour before").tag(60)
                    }
                }
                SettingsRow("Only if I've used") {
                    Picker("", selection: $model.settings.minUsedPercent) {
                        Text("Any amount").tag(0.0); Text("≥ 25%").tag(25.0); Text("≥ 50%").tag(50.0); Text("≥ 80%").tag(80.0)
                    }
                }
            }
            SettingsGroup("General") {
                SettingsRow("Reminders list") {
                    TextField("", text: $model.settings.listName).textFieldStyle(.roundedBorder).frame(width: 130)
                }
                SettingsRow("Open at login") {
                    Toggle("", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) })).labelsHidden()
                }
            }
            DisclosureGroup(isExpanded: $showAdvanced) {
                SettingsGroup(nil) {
                    SettingsRow("Background check") {
                        Picker("", selection: $model.pollMinutes) {
                            Text("Every 5 min").tag(5); Text("Every 10 min").tag(10); Text("Every 30 min").tag(30)
                        }
                    }
                    SettingsRow("Live Codex check", detail: "codex app-server; off = session logs only") {
                        Toggle("", isOn: $model.useLive).labelsHidden()
                    }
                    SettingsRow("codex path") {
                        TextField("auto", text: $model.codexPath).textFieldStyle(.roundedBorder).frame(width: 130)
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("ADVANCED").font(.caption2.weight(.semibold)).tracking(0.6).foregroundStyle(.secondary)
            }
            Text("Reads limits locally. Writes only to its own Reminders list.")
                .font(.caption2).foregroundStyle(.tertiary).padding(.horizontal, 2)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .pickerStyle(.menu)
    }

    private func providerBinding(_ p: Provider) -> Binding<Bool> {
        Binding(get: { model.isEnabled(p) }, set: { model.toggleProvider(p, enabled: $0) })
    }

    private func windowBinding(_ minutes: Int) -> Binding<Bool> {
        Binding(get: { !model.settings.disabledWindowMinutes.contains(minutes) },
                set: { model.toggleWindow(minutes, enabled: $0) })
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String?
    @ViewBuilder var content: () -> Content
    init(_ title: String?, @ViewBuilder content: @escaping () -> Content) { self.title = title; self.content = content }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title { SectionHeader(title: title, detail: nil) }
            // Each row draws a divider on top; the mask hides the first one so only separators remain.
            VStack(spacing: 0) { content() }
                .mask(Rectangle().padding(.top, 1))
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
        }
    }
}

struct SettingsRow<Control: View>: View {
    let label: String
    var detail: String?
    @ViewBuilder var control: () -> Control
    init(_ label: String, detail: String? = nil, @ViewBuilder control: @escaping () -> Control) {
        self.label = label; self.detail = detail; self.control = control
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.callout)
                if let detail { Text(detail).font(.caption2).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            control().fixedSize()
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .overlay(alignment: .top) { Divider().padding(.leading, 10).opacity(0.6) }
    }
}
