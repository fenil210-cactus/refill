import Foundation

/// One rate-limit window reported by a provider, e.g. Codex's 5-hour or weekly window.
public struct LimitWindow: Equatable, Codable, Sendable {
    public var provider: String        // "codex", "claude"
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
        let base = Self.providerName(provider)
        if limitId == provider { return base }
        return "\(base) \(limitName ?? limitId)"
    }

    public static func providerName(_ provider: String) -> String {
        switch provider {
        case "codex": return "Codex"
        case "claude": return "Claude"
        default: return provider.capitalized
        }
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

public enum Provider: String, CaseIterable, Codable, Sendable {
    case codex, claude

    public var displayName: String { LimitWindow.providerName(rawValue) }
}

public enum UsageSource: String, Equatable, Codable, Sendable {
    case live            // `codex app-server` → account/rateLimits/read
    case sessionLog      // last token_count event in ~/.codex/sessions
    case statusLine      // Claude Code status line input, saved by `Refill claude-statusline`
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
    public var listName: String = Self.defaultListName
    public static let defaultListName = "AI Limits"
    /// v1.0 default, from when Refill only tracked Codex. Migrated to `defaultListName` (the list is renamed in place).
    public static let legacyListName = "Codex Limits"
    /// Minutes after a reset before its reminder is auto-completed.
    public var completeAfterMinutes: Int = 30
    /// Providers to skip entirely, e.g. "claude". Their pending reminders are removed.
    public var disabledProviders: Set<String> = []

    public init() {}

    /// Missing keys keep their defaults, so settings saved by older versions still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = RefillSettings()
        leadMinutes = try c.decodeIfPresent(Int.self, forKey: .leadMinutes) ?? d.leadMinutes
        earlyHeadsUpMinutes = try c.decodeIfPresent(Int.self, forKey: .earlyHeadsUpMinutes) ?? d.earlyHeadsUpMinutes
        minUsedPercent = try c.decodeIfPresent(Double.self, forKey: .minUsedPercent) ?? d.minUsedPercent
        disabledWindowMinutes = try c.decodeIfPresent(Set<Int>.self, forKey: .disabledWindowMinutes) ?? d.disabledWindowMinutes
        let savedList = try c.decodeIfPresent(String.self, forKey: .listName) ?? d.listName
        listName = savedList == Self.legacyListName ? Self.defaultListName : savedList
        completeAfterMinutes = try c.decodeIfPresent(Int.self, forKey: .completeAfterMinutes) ?? d.completeAfterMinutes
        disabledProviders = try c.decodeIfPresent(Set<String>.self, forKey: .disabledProviders) ?? d.disabledProviders
    }
}
