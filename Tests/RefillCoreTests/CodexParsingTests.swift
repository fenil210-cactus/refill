import Foundation
import Testing
@testable import RefillCore

struct CodexParsingTests {
    @Test func appServerResultUsesEveryLimitBucketWithWindows() throws {
        // Shape captured from `codex app-server` 0.147 → account/rateLimits/read.
        let json = """
        {"rateLimits":{"limitId":"codex","primary":{"usedPercent":100,"windowDurationMins":300,"resetsAt":1792333969},
          "secondary":{"usedPercent":22,"windowDurationMins":10080,"resetsAt":1792874601},"planType":"team",
          "rateLimitReachedType":"workspace_owner_credits_depleted"},
         "rateLimitsByLimitId":{
           "codex":{"limitId":"codex","primary":{"usedPercent":100,"windowDurationMins":300,"resetsAt":1792333969},
             "secondary":{"usedPercent":22,"windowDurationMins":10080,"resetsAt":1792874601},"planType":"team"},
           "premium":{"limitId":"premium","primary":null,"secondary":null}}}
        """
        let obj = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let snap = try #require(CodexParsing.parseAppServerResult(obj))

        #expect(snap.planType == "team")
        #expect(snap.source == .live)
        #expect(snap.windows.map(\.key) == ["codex/codex/300", "codex/codex/10080"])
        #expect(snap.windows[0].usedPercent == 100)
        #expect(snap.windows[1].resetsAt == Date(timeIntervalSince1970: 1792874601))
    }

    @Test func sessionLogLineWithAbsoluteResets() throws {
        let line = """
        {"timestamp":"2026-10-18T10:18:38.371Z","type":"event_msg","payload":{"type":"token_count","info":null,
         "rate_limits":{"limit_id":"codex","primary":{"used_percent":95.0,"window_minutes":300,"resets_at":1792333969},
         "secondary":{"used_percent":21.0,"window_minutes":10080,"resets_at":1792874601},"plan_type":"team"}}}
        """
        let snap = try #require(CodexParsing.parseSessionLogLine(Substring(line)))
        #expect(snap.source == .sessionLog)
        #expect(snap.windows.map(\.usedPercent) == [95, 21])
        #expect(snap.windows[0].resetsAt == Date(timeIntervalSince1970: 1792333969))
    }

    @Test func legacySessionLogLineResolvesRelativeResetsAgainstEventTime() throws {
        let line = """
        {"timestamp":"2025-09-01T12:00:00Z","type":"event_msg","payload":{"type":"token_count",
         "rate_limits":{"primary":{"used_percent":40,"window_minutes":300,"resets_in_seconds":3600}}}}
        """
        let snap = try #require(CodexParsing.parseSessionLogLine(Substring(line)))
        let eventTime = try #require(CodexParsing.parseISO("2025-09-01T12:00:00Z"))
        #expect(snap.windows.first?.resetsAt == eventTime.addingTimeInterval(3600))
        #expect(snap.windows.first?.limitId == "codex")
    }

    @Test func linesWithoutWindowsAreSkipped() {
        let premium = #"{"payload":{"type":"token_count","rate_limits":{"limit_id":"premium","primary":null,"secondary":null}}}"#
        #expect(CodexParsing.parseSessionLogLine(Substring(premium)) == nil)
        #expect(CodexParsing.parseSessionLogLine(Substring(#"{"type":"response_item"}"#)) == nil)
        #expect(CodexParsing.parseSessionLogLine("not json \"rate_limits\"") == nil)
    }

    @Test func newestUsableEventWinsWhenReadingBackwardsAcrossChunks() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        func event(_ used: Int) -> String {
            #"{"timestamp":"2026-10-18T10:00:00Z","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":\#(used),"window_minutes":300,"resets_at":1792333969}}}}"#
        }
        let filler = String(repeating: "x", count: 5000)
        let premium = #"{"payload":{"type":"token_count","rate_limits":{"limit_id":"premium","primary":null}}}"#
        let lines = [event(10), #"{"pad":"\#(filler)"}"#, event(60), #"{"pad":"\#(filler)"}"#, premium]
        let url = dir.appendingPathComponent("rollout.jsonl")
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)

        // Tiny chunks force lines to straddle chunk boundaries.
        let snap = try #require(CodexSessionLogSource.lastSnapshot(in: url, chunkSize: 700))
        #expect(snap.windows.first?.usedPercent == 60)
    }
}
