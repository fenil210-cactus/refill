import AppKit
import RefillCore
import SwiftUI

/// `Refill debug-snapshot <out.png> [--settings] [--light]`: renders the real popover offscreen with your
/// current limits, for README screenshots and UI checks. Reads reminders from the app's last sync report
/// rather than Reminders, so it never asks for Reminders access.
@MainActor
enum Snapshot {
    static func run(_ args: [String]) {
        let out = args.dropFirst().first { !$0.hasPrefix("--") } ?? "refill-popover.png"
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)

        let model = AppModel()
        var result = SyncResult()
        for p in model.enabledProviders {
            let (snap, err) = UsageFetcher.fetch(p, codexPathOverride: model.codexPath.isEmpty ? nil : model.codexPath, useLive: model.useLive)
            result.snapshots[p.rawValue] = snap
            result.errors[p.rawValue] = err
        }
        if let data = try? Data(contentsOf: SyncReport.url) {
            let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
            if let report = try? dec.decode(SyncReport.self, from: data) {
                result.reminders = report.openReminders.map { key, due in
                    ManagedReminder(id: key, key: key, title: "", notes: nil, dueDate: due, alarmDates: [due], isCompleted: false)
                }
            }
        }
        model.result = result

        let view = MenuView(model: model, showSettings: args.contains("--settings"))
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, args.contains("--light") ? .light : .dark)
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: args.contains("--light") ? .aqua : .darkAqua)
        let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 340, height: 400),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        window.setContentSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))   // let menus/toggles finish their first layout

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { exit(1) }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
        do { try png.write(to: URL(fileURLWithPath: out)); print("wrote \(out) (\(Int(host.bounds.width))×\(Int(host.bounds.height)) pt)") }
        catch { FileHandle.standardError.write("\(error.localizedDescription)\n".data(using: .utf8)!); exit(1) }
    }
}
