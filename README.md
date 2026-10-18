<p align="center">
  <img src="docs/icon.png" width="112" alt="Refill icon">
</p>

<h1 align="center">Refill</h1>
<p align="center"><b>Never miss a Codex or Claude Code limit reset.</b><br>
Refill puts your Codex and Claude Code 5-hour and weekly limit resets into Apple Reminders automatically,<br>
so your Mac, iPhone and Apple Watch ping you the moment you can code again.</p>

<p align="center">
  <a href="https://github.com/fenil210-cactus/refill/releases/latest"><img src="https://img.shields.io/github/v/release/fenil210-cactus/refill?color=10b981&label=release" alt="release"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-black" alt="macOS 13+">
  <img src="https://img.shields.io/badge/size-under%202%20MB-10b981" alt="size">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT"></a>
</p>

---

You hit the Codex limit. It says *"try again at 8:02 PM"*. You forget. You come back at 11.

**Refill fixes that.** It lives in your menu bar, reads your real Codex and Claude Code limits, and keeps one reminder per window
in an **AI Limits** list, alarmed for the exact reset time. When the reset moves, the reminder moves with it.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/fenil210-cactus/refill/main/install.sh | bash
```

Or with Homebrew:

```bash
brew install --cask fenil210-cactus/tap/refill
```

That's it. Click **Allow** when macOS asks for Reminders access. No Xcode, no developer account, no "unidentified developer" dialog.

<details>
<summary>Prefer to build it yourself?</summary>

```bash
git clone https://github.com/fenil210-cactus/refill && cd refill
./scripts/build-app.sh          # needs only Xcode Command Line Tools (xcode-select --install)
cp -R dist/Refill.app ~/Applications/ && open ~/Applications/Refill.app
```
</details>

Uninstall: `curl -fsSL https://raw.githubusercontent.com/fenil210-cactus/refill/main/install.sh | bash -s -- --uninstall`

## What you get

- **Menu bar meter:** `⚡ 72%` while you work, and a countdown `⏳ 2h 07m` when you're blocked.
- **Real reminders:** native Apple Reminders with alarms, synced through iCloud to your iPhone and Watch.
- **One reminder per window:** 5-hour and weekly, for each provider. It's updated in place and never duplicated.
- **Two providers:** Codex and Claude Code side by side; switch either off in Settings.
- **Optional heads-up:** 5, 15 or 30 minutes before the reset, or an extra alert an hour ahead.
- **Noise control:** only remind when you've used at least 25%, 50% or 80%, or turn a window off.
- **CLI for terminal people:** `refill status`, `refill sync`, `refill doctor`.

```text
$ refill status
Codex team · source: live
  Codex 5-hour  ████████████████████ 100%  resets 18 Oct 2026 at 8:02 PM
  Codex weekly  ████░░░░░░░░░░░░░░░░  22%  resets 25 Oct 2026 at 2:13 AM
Claude  · source: Claude Code status line, 18 Oct 2026 at 3:41 PM
  Claude 5-hour  ████████░░░░░░░░░░░░  41%  resets 18 Oct 2026 at 6:00 PM
  Claude weekly  ███░░░░░░░░░░░░░░░░░  17%  resets 23 Oct 2026 at 9:00 AM
```

## How it stays right

Limits aren't static: windows roll over, OpenAI sometimes resets everyone early, plans change. Refill re-derives the truth on every sync
and reconciles your reminders against it:

| Situation | What Refill does |
|---|---|
| You send a Codex or Claude Code message | A usage event lands on disk; Refill notices within seconds and re-syncs |
| Reset time moves (early reset, plan change) | Moves the **same** reminder to the new time |
| Window resets, a new one starts | Lets the old reminder ring, then auto-completes it and schedules the next |
| You tick a reminder off yourself | Respects it and won't recreate it for that reset |
| Usage drops below your threshold | Removes the pending reminder |
| Mac sleeps, or you change time zone | Re-syncs on wake and on time zone change |
| Duplicate reminders (e.g. two Macs) | Collapses them to one |
| Codex offline or logged out | Falls back to your local Codex session logs |

### Where the numbers come from

**Codex**

1. **Live:** Refill asks your installed Codex CLI over its own `codex app-server` JSON-RPC protocol (`account/rateLimits/read`),
   the interface Codex's own clients use. Refill never reads or stores your auth tokens; Codex handles auth.
2. **Offline fallback:** the latest `token_count` event in `~/.codex/sessions/**.jsonl`, which carries `rate_limits.resets_at`.

**Claude Code** (Pro and Max plans)

Claude Code passes `rate_limits.five_hour` and `rate_limits.seven_day` to your
[status line](https://code.claude.com/docs/en/statusline) command after each message. Turn on **Settings › Read Claude Code limits**
and Refill sets `~/.claude/settings.json` → `statusLine.command` to `Refill claude-statusline --then '<your old command>'`:
it saves just the `rate_limits` object to `~/Library/Application Support/Refill/claude/`, then runs your old status line with the
same input, so it looks exactly as before. Turning the setting off restores your previous status line. Refill never reads Claude's
auth tokens. Claude cards appear after your next Claude Code message. From a terminal: `refill claude-connect` / `refill claude-disconnect`
(the uninstaller disconnects for you).

Everything stays on your Mac. Refill makes no network requests of its own and has no analytics.

## FAQ

**Do I need an Apple Developer account or Xcode?** No. Refill is ad-hoc signed and installed with `curl`, which macOS doesn't quarantine,
so Gatekeeper doesn't block it. Building from source needs only the free Command Line Tools.

**Why Reminders and not plain notifications?** Reminders sync to your iPhone and Apple Watch, survive reboots, ring even if Refill isn't
running, and you can snooze them.

**macOS asked for Reminders access again after an update.** It can happen on some macOS versions because builds are ad-hoc signed.
Click Allow once more; your existing reminders are picked up, not duplicated.

**Nothing shows up.** Run `refill doctor`. It shows the Codex path it found, the latest log event, and the last sync result.

## Roadmap

- [x] Claude Code limits (5-hour and weekly) as a second provider
- [x] Homebrew cask
- [ ] Stable self-signed identity so updates always keep the Reminders permission

## Develop

```bash
./scripts/test.sh               # swift-testing suite (planner + parsers)
swift run Refill status         # run the CLI from source
./scripts/build-app.sh          # universal .app + zip in dist/
```

Launch video: `cd video && npm install && npm run render` (Remotion; the score is synthesized by `scripts/music.mjs`).

Code map: `Sources/RefillCore`: `CodexParsing` (both data shapes), `CodexSources` (app-server client, log reader, codex locator),
`ClaudeSources` (status line hook, `rate_limits` parser, `~/.claude/settings.json` connect/disconnect),
`ReminderPlanner` (pure reconcile logic, unit tested), `RemindersStore` (EventKit). `Sources/Refill`: SwiftUI menu bar app and CLI.

MIT © Fenil Ramoliya. Not affiliated with OpenAI, Anthropic or Apple.
