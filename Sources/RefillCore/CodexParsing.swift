import Foundation

/// Tolerant parsers for the two shapes Codex uses for rate limits:
/// camelCase from `codex app-server` and snake_case in session rollout logs.
/// Unknown fields are ignored so new Codex versions don't break parsing.
public enum CodexParsing {

    /// Parses the `result` of `account/rateLimits/read`.
    public static func parseAppServerResult(_ result: [String: Any], now: Date = Date()) -> UsageSnapshot? {
        var buckets: [[String: Any]] = []
        if let byId = result["rateLimitsByLimitId"] as? [String: Any] {
            buckets = byId.keys.sorted().compactMap { byId[$0] as? [String: Any] }
        }
        if buckets.isEmpty, let single = result["rateLimits"] as? [String: Any] {
            buckets = [single]
        }
        guard !buckets.isEmpty else { return nil }

        var windows: [LimitWindow] = []
        var plan: String?
        var reached: String?
        for bucket in buckets {
            let limitId = (bucket["limitId"] as? String) ?? "codex"
            let limitName = bucket["limitName"] as? String
            plan = plan ?? (bucket["planType"] as? String)
            if limitId == "codex" { reached = bucket["rateLimitReachedType"] as? String }
            for slot in ["primary", "secondary"] {
                guard let w = bucket[slot] as? [String: Any],
                      let used = number(w["usedPercent"]),
                      let mins = number(w["windowDurationMins"]),
                      let resets = number(w["resetsAt"]) else { continue }
                windows.append(LimitWindow(provider: "codex", limitId: limitId, limitName: limitName,
                                           usedPercent: used, windowMinutes: Int(mins),
                                           resetsAt: Date(timeIntervalSince1970: resets)))
            }
        }
        return UsageSnapshot(windows: dedupe(windows), planType: plan, limitReachedType: reached,
                             observedAt: now, source: .live)
    }

    /// Parses one rollout JSONL line. Returns nil unless it's a token_count event with windows.
    public static func parseSessionLogLine(_ line: Substring) -> UsageSnapshot? {
        guard line.contains("\"rate_limits\""),
              let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let payload = (obj["payload"] as? [String: Any]) ?? obj
        guard let rl = payload["rate_limits"] as? [String: Any] else { return nil }
        let observed = (obj["timestamp"] as? String).flatMap(parseISO) ?? Date()

        let limitId = (rl["limit_id"] as? String) ?? "codex"
        let limitName = rl["limit_name"] as? String
        var windows: [LimitWindow] = []
        for slot in ["primary", "secondary"] {
            guard let w = rl[slot] as? [String: Any],
                  let used = number(w["used_percent"]),
                  let mins = number(w["window_minutes"]) else { continue }
            let resets: Date
            if let at = number(w["resets_at"]) {
                resets = Date(timeIntervalSince1970: at)
            } else if let inSec = number(w["resets_in_seconds"]) {
                resets = observed.addingTimeInterval(inSec)   // older Codex versions
            } else { continue }
            windows.append(LimitWindow(provider: "codex", limitId: limitId, limitName: limitName,
                                       usedPercent: used, windowMinutes: Int(mins), resetsAt: resets))
        }
        guard !windows.isEmpty else { return nil }
        return UsageSnapshot(windows: windows, planType: rl["plan_type"] as? String,
                             limitReachedType: rl["rate_limit_reached_type"] as? String,
                             observedAt: observed, source: .sessionLog)
    }

    static func dedupe(_ windows: [LimitWindow]) -> [LimitWindow] {
        var seen = Set<String>()
        return windows.filter { seen.insert($0.key).inserted }
    }

    static func number(_ any: Any?) -> Double? {
        switch any {
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s)
        default: return nil
        }
    }

    static func parseISO(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}
