import AppKit
import RefillCore
import SwiftUI

// `Refill status|sync|--help` runs headless; no arguments launches the menu bar app.
if CLI.run(Array(CommandLine.arguments.dropFirst())) { exit(0) }
RefillApp.main()

struct RefillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: delegate.model)
        } label: {
            MenuBarLabel(model: delegate.model)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: model.isBlocked ? "hourglass" : "bolt.fill")
            if !model.menuBarTitle.isEmpty { Text(model.menuBarTitle).monospacedDigit() }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor lazy var model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        MainActor.assumeIsolated { model.start() }
    }
}
