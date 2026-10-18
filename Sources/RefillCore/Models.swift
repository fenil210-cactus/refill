import Foundation

/// One rate-limit window reported by a provider, e.g. Codex's 5-hour or weekly window.
public struct LimitWindow: Equatable, Codable, Sendable {
    public var provider: String        // "codex"
    public var limitId: String         // "codex", "premium", ...
    public var limitName: String?
    public var usedPercent: Double
    public var windowMinutes: Int
    public var resetsAt: Date

    public init(provider: String, limitId: String, limitName: String? = nil,
                usedPercent: Double, windowMinutes: Int, resetsAt: Date) {
        self.provider = provider
        self.limitId = limitId
        self.limitName = limitName
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
    }

    /// Stable identity of a window across syncs. The window length (not "primary"/"secondary")
    /// is used so a reminder survives if a provider reorders its windows.
    public var key: String { "\(provider)/\(limitId)/\(windowMinutes)" }

    public var windowLabel: String { Self.label(forMinutes: windowMinutes) }

    public var providerLabel: String {
        let base = provider == "codex" ? "Codex" : provider.capitalized
        if limitId == provider { return base }
        return "\(base) \(limitName ?? limitId)"
    }

    public static func label(forMinutes minutes: Int) -> String {
        switch minutes {
        case 10080: return "weekly"
        case 1440: return "daily"
        case let m where m % 1440 == 0: return "\(m / 1440)-day"
        case let m where m % 60 == 0: return "\(m / 60)-hour"
        default: return "\(minutes)-minute"
        }
    }

    public var shortLabel: String {
        switch windowMinutes {
        case 10080: return "Week"
        case let m where m % 1440 == 0: return "\(m / 1440)d"
        case let m where m % 60 == 0: return "\(m / 60)h"
        default: return "\(windowMinutes)m"
        }
    }
}

public enum UsageSource: String, Equatable, Codable, Sendable {
    case live            // `codex app-server` → account/rateLimits/read
    case sessionLog      // last token_count event in ~/.codex/sessions
}

public struct UsageSnapshot: Equatable, Codable, Sendable {
    public var windows: [LimitWindow]
    public var planType: String?
    public var limitReachedType: String?
    public var observedAt: Date
    public var source: UsageSource

    public init(windows: [LimitWindow], planType: String?, limitReachedType: String?,
                observedAt: Date, source: UsageSource) {
        self.windows = windows
        self.planType = planType
        self.limitReachedType = limitReachedType
        self.observedAt = observedAt
        self.source = source
    }
}

public struct RefillSettings: Equatable, Codable, Sendable {
    /// Minutes before the reset at which to alert. 0 = exactly at reset.
    public var leadMinutes: Int = 0
    /// Also alert this many minutes before reset (0 = off).
    public var earlyHeadsUpMinutes: Int = 0
    /// Skip reminders for windows used less than this.
    public var minUsedPercent: Double = 0
    /// Keys of windows to ignore, matched on window length: e.g. 300 (5h) or 10080 (weekly).
    public var disabledWindowMinutes: Set<Int> = []
    public var listName: String = "Codex Limits"
    /// Minutes after a reset before its reminder is auto-completed.
    public var completeAfterMinutes: Int = 30

    public init() {}
}
