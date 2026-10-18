import AppKit
import CoreServices
import Foundation
import RefillCore
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published var result: SyncResult?
    @Published var syncing = false
    @Published var now = Date()
    @Published var settings: RefillSettings { didSet { saveSettings(); scheduleSync(after: 1) } }
    @Published var codexPath: String { didSet { UserDefaults.standard.set(codexPath, forKey: "codexPath") } }
    @Published var useLive: Bool { didSet { UserDefaults.standard.set(useLive, forKey: "useLive") } }
    @Published var pollMinutes: Int { didSet { UserDefaults.standard.set(pollMinutes, forKey: "pollMinutes"); restartPoll() } }
    @Published var launchAtLogin: Bool = false
    @Published var claudeConnected = ClaudeStatusLine.isConnected
    @Published var claudeConnectError: String?

    private let engine = SyncEngine()
    private var pollTimer: Timer?
    private var tickTimer: Timer?
    private var resetTimer: Timer?
    private var pendingSync: DispatchWorkItem?
    private var fsStream: FSEventStreamRef?

    init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: "settings"), let s = try? JSONDecoder().decode(RefillSettings.self, from: data) {
            settings = s
        } else { settings = RefillSettings() }
        codexPath = d.string(forKey: "codexPath") ?? ""
        useLive = d.object(forKey: "useLive") as? Bool ?? true
        pollMinutes = d.object(forKey: "pollMinutes") as? Int ?? 10
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func start() {
        if !UserDefaults.standard.bool(forKey: "didOnboard") {
            UserDefaults.standard.set(true, forKey: "didOnboard")
            setLaunchAtLogin(true)
        }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
        restartPoll()
        watchUsageFiles()
        refreshClaudeConnection()
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.scheduleSync(after: 5) }
        }
        NotificationCenter.default.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.scheduleSync(after: 1) }
        }
        syncNow()
    }

    // MARK: Sync triggers

    /// `live: false` reads only the local session log: cheap enough to run while Codex is busy.
    func syncNow(live: Bool = true) {
        guard !syncing else { resyncQueued = true; return }
        syncing = true
        let s = settings, path = codexPath.isEmpty ? nil : codexPath, useLive = live && self.useLive
        Task {
            let r = await engine.sync(settings: s, codexPathOverride: path, useLive: useLive, known: self.result?.snapshots ?? [:])
            self.result = r
            SyncReport(r).save()
            self.syncing = false
            self.now = Date()
            self.scheduleResetRefresh()
            if self.resyncQueued { self.resyncQueued = false; self.scheduleSync(after: 2, live: false) }
        }
    }
    private var resyncQueued = false

    /// Throttles bursts: Codex appends log lines constantly during a turn, so keep the first pending
    /// sync instead of pushing it back (a debounce would never fire during a long agent run).
    func scheduleSync(after seconds: Double, live: Bool = true) {
        if let p = pendingSync, !p.isCancelled { return }
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.pendingSync = nil; self?.syncNow(live: live) }
        }
        pendingSync = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    private func restartPoll() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(max(2, pollMinutes) * 60), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.syncNow() }
        }
    }

    /// Re-check right after the next reset so the following window's reminder is set up promptly.
    private func scheduleResetRefresh() {
        resetTimer?.invalidate()
        guard let next = result?.windows.map(\.resetsAt).filter({ $0 > Date() }).min() else { return }
        let delay = next.timeIntervalSinceNow + 60
        resetTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.syncNow() }
        }
    }

    /// "Usage changed" signals: Codex appends a token_count event to its session log on every turn, and
    /// Claude Code's status line (via `Refill claude-statusline`) rewrites Refill's Claude file.
    private func watchUsageFiles() {
        try? FileManager.default.createDirectory(at: ClaudeStatusLine.directory, withIntermediateDirectories: true)
        let paths = [CodexLocator.codexHome.appendingPathComponent("sessions").path, ClaudeStatusLine.directory.path]
            .filter { FileManager.default.fileExists(atPath: $0) }
        guard !paths.isEmpty else { return }
        var ctx = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                       retain: nil, release: nil, copyDescription: nil)
        let cb: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let model = Unmanaged<AppModel>.fromOpaque(info).takeUnretainedValue()
            Task { @MainActor in model.scheduleSync(after: 8, live: false) }
        }
        guard let stream = FSEventStreamCreate(nil, cb, &ctx, paths as CFArray,
                                               FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 3,
                                               FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)) else { return }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        fsStream = stream
    }

    // MARK: Settings

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: "settings") }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { NSLog("Refill: login item change failed: \(error)") }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func toggleWindow(_ minutes: Int, enabled: Bool) {
        if enabled { settings.disabledWindowMinutes.remove(minutes) } else { settings.disabledWindowMinutes.insert(minutes) }
    }

    /// One switch per provider. For Claude Code that switch *is* the status line connection,
    /// so turning it off also hands Claude Code its previous status line back.
    func toggleProvider(_ p: Provider, enabled: Bool) {
        if enabled { settings.disabledProviders.remove(p.rawValue) } else { settings.disabledProviders.insert(p.rawValue) }
        if p == .claude, enabled != claudeConnected { setClaudeConnected(enabled) }
    }

    func isEnabled(_ p: Provider) -> Bool {
        !settings.disabledProviders.contains(p.rawValue) && (p != .claude || claudeConnected)
    }

    /// Points Claude Code's status line at this binary (keeping the user's existing status line), or undoes it.
    func setClaudeConnected(_ on: Bool) {
        do {
            if on {
                guard let exe = Bundle.main.executableURL?.resolvingSymlinksInPath().path else { return }
                try ClaudeStatusLine.connect(refillPath: exe)
                settings.disabledProviders.remove(Provider.claude.rawValue)
            } else {
                try ClaudeStatusLine.disconnect()
            }
            claudeConnectError = nil
        } catch { claudeConnectError = error.localizedDescription }
        claudeConnected = ClaudeStatusLine.isConnected
        scheduleSync(after: 1, live: false)
    }

    /// Re-points an existing connection if Refill.app moved (e.g. reinstalled elsewhere).
    private func refreshClaudeConnection() {
        if claudeConnected { setClaudeConnected(true) }
    }

    // MARK: Derived

    var enabledProviders: [Provider] { Provider.allCases.filter { !settings.disabledProviders.contains($0.rawValue) } }

    /// Sections in the popover: Claude only appears once connected, or as a "Connect" card if Claude Code is installed.
    var visibleProviders: [Provider] {
        enabledProviders.filter { $0 != .claude || claudeConnected || ClaudeStatusLine.isInstalled }
    }

    func windows(for p: Provider) -> [LimitWindow] {
        (result?.snapshots[p.rawValue]?.windows ?? []).sorted { ($0.limitId != p.rawValue ? 1 : 0, $0.windowMinutes) < ($1.limitId != p.rawValue ? 1 : 0, $1.windowMinutes) }
    }

    var windows: [LimitWindow] { enabledProviders.flatMap { windows(for: $0) } }

    /// Menu bar text: countdown when you're blocked, otherwise the tightest main window's usage across providers.
    var menuBarTitle: String {
        if let blocked = windows.filter({ $0.usedPercent >= 100 && $0.resetsAt > now }).max(by: { $0.resetsAt < $1.resetsAt }) {
            return Fmt.countdown(to: blocked.resetsAt, from: now)
        }
        let main = windows.filter { $0.limitId == $0.provider }
        guard !main.isEmpty else { return "" }
        let used = main.map { $0.resetsAt <= now ? 0 : $0.usedPercent }.max() ?? 0
        return "\(Int(used.rounded()))%"
    }

    var isBlocked: Bool { windows.contains { $0.usedPercent >= 100 && $0.resetsAt > now } }

    func reminder(for w: LimitWindow) -> ManagedReminder? {
        result?.reminders.first { $0.key == w.key }
    }

    func openReminders() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
    }

    func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!)
    }
}

enum Fmt {
    static func ago(_ date: Date, now: Date = Date()) -> String {
        let m = Int(now.timeIntervalSince(date) / 60)
        switch m {
        case ..<1: return "just now"
        case ..<60: return "\(m)m ago"
        case ..<1440: return "\(m / 60)h ago"
        default: return "\(m / 1440)d ago"
        }
    }

    static func countdown(to date: Date, from now: Date = Date()) -> String {
        let s = max(0, Int(date.timeIntervalSince(now)))
        let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(String(format: "%02d", m))m" }
        return "\(max(m, s > 0 ? 1 : 0))m"
    }

    static func resetTime(_ date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let t = DateFormatter()
        t.timeStyle = .short
        t.dateStyle = .none
        if cal.isDate(date, inSameDayAs: now) { return "today \(t.string(from: date))" }
        if let tmr = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(date, inSameDayAs: tmr) {
            return "tomorrow \(t.string(from: date))"
        }
        let d = DateFormatter()
        d.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return "\(d.string(from: date)), \(t.string(from: date))"
    }
}
