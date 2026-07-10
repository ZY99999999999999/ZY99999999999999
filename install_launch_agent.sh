#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PLIST="$HOME/Library/LaunchAgents/com.didi.codex-pet.plist"

mkdir -p "$HOME/Library/LaunchAgents"
sed \
  -e "s#__WATCHER_SCRIPT__#${ROOT}/codex_pet_watcher.sh#g" \
  "$ROOT/com.didi.codex-pet.plist.template" > "$PLIST"

chmod +x "$ROOT/codex_pet_watcher.sh"
launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || launchctl unload "$PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || launchctl load "$PLIST"
launchctl kickstart -k "gui/$(id -u)/com.didi.codex-pet" >/dev/null 2>&1 || true
echo "Codex Pet launch agent installed: $PLIST"
