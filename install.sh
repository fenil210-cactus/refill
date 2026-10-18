#!/usr/bin/env bash
# Refill installer: Codex usage limits → Apple Reminders.
#   Install:    curl -fsSL https://raw.githubusercontent.com/fenil210-cactus/refill/main/install.sh | bash
#   Uninstall:  curl -fsSL https://raw.githubusercontent.com/fenil210-cactus/refill/main/install.sh | bash -s -- --uninstall
set -euo pipefail

REPO="fenil210-cactus/refill"
APP_NAME="Refill.app"
ZIP_URL="${REFILL_ZIP_URL:-https://github.com/$REPO/releases/latest/download/Refill.zip}"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "Refill is a macOS app."
major=$(sw_vers -productVersion | cut -d. -f1)
(( major >= 13 )) || die "Refill needs macOS 13 Ventura or newer (you have $(sw_vers -productVersion))."

cli_link_dir() {
  for d in /opt/homebrew/bin /usr/local/bin; do [[ -d "$d" && -w "$d" ]] && { echo "$d"; return; }; done
  mkdir -p "$HOME/.local/bin" && echo "$HOME/.local/bin"
}

quit_running() {
  osascript -e 'tell application id "com.fenil210.refill" to quit' >/dev/null 2>&1 || true
  pkill -f "$APP_NAME/Contents/MacOS/Refill" >/dev/null 2>&1 || true
  sleep 1
}

if [[ "${1:-}" == "--uninstall" ]]; then
  bold "Uninstalling Refill"
  quit_running
  for d in /Applications "$HOME/Applications"; do
    [[ -x "$d/$APP_NAME/Contents/MacOS/Refill" ]] && "$d/$APP_NAME/Contents/MacOS/Refill" unregister-login 2>/dev/null || true
    # Give Claude Code its previous status line back before the binary it points at disappears.
    [[ -x "$d/$APP_NAME/Contents/MacOS/Refill" ]] && "$d/$APP_NAME/Contents/MacOS/Refill" claude-disconnect >/dev/null 2>&1 || true
  done
  for d in /Applications "$HOME/Applications"; do
    [[ -d "$d/$APP_NAME" ]] && rm -rf "$d/$APP_NAME" && ok "removed $d/$APP_NAME"
  done
  for d in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
    [[ -L "$d/refill" ]] && rm -f "$d/refill" && ok "removed $d/refill"
  done
  rm -rf "$HOME/Library/Application Support/Refill"
  defaults delete com.fenil210.refill >/dev/null 2>&1 || true
  ok "done. Your 'AI Limits' list in Reminders was left in place; delete it there if you like."
  exit 0
fi

bold "Installing Refill"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
curl -fsSL --retry 3 "$ZIP_URL" -o "$tmp/Refill.zip" || die "download failed: $ZIP_URL"
ditto -x -k "$tmp/Refill.zip" "$tmp/x"
[[ -d "$tmp/x/$APP_NAME" ]] || die "archive didn't contain $APP_NAME"
ok "downloaded $(du -h "$tmp/Refill.zip" | cut -f1 | tr -d ' ')"

dest=/Applications
[[ -w "$dest" ]] || { dest="$HOME/Applications"; mkdir -p "$dest"; }
quit_running
rm -rf "${dest:?}/$APP_NAME"
mv "$tmp/x/$APP_NAME" "$dest/"
# curl doesn't set quarantine, but clear it in case the zip came from a browser.
xattr -dr com.apple.quarantine "$dest/$APP_NAME" 2>/dev/null || true
ok "installed $dest/$APP_NAME"

bin_dir=$(cli_link_dir)
ln -sf "$dest/$APP_NAME/Contents/MacOS/Refill" "$bin_dir/refill"
ok "CLI: $bin_dir/refill  (try: refill status)"

if ! command -v codex >/dev/null 2>&1 && [[ ! -x /opt/homebrew/bin/codex && ! -x /usr/local/bin/codex ]]; then
  printf '  \033[33m!\033[0m Codex CLI not found on PATH. Refill will read ~/.codex logs; install Codex for live limits.\n'
fi

open "$dest/$APP_NAME"
echo
bold "⚡ Refill is in your menu bar."
echo "  Click Allow when macOS asks for Reminders access. Reminders land in an 'AI Limits' list,"
echo "  and sync to your iPhone and Apple Watch if iCloud Reminders is on."
