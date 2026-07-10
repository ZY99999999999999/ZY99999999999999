#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_BUNDLE="$ROOT/CodexPet.app"
PET_BIN="$ROOT/codex-pet-native"
CODEX_PROCESS_PATTERNS=(
  "/Applications/Codex.app/Contents/MacOS/Codex"
  "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"
  "/Applications/ChatGPT.app/Contents/Resources/codex"
)

is_codex_running() {
  local pattern
  for pattern in "${CODEX_PROCESS_PATTERNS[@]}"; do
    if pgrep -f "^${pattern}" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

is_pet_running() {
  pgrep -f "^${PET_BIN}$" >/dev/null 2>&1
}

start_pet() {
  /usr/bin/open "$APP_BUNDLE"
}

stop_pet() {
  local pids
  pids="$(pgrep -f "^${PET_BIN}$" || true)"
  if [ -n "$pids" ]; then
    kill $pids >/dev/null 2>&1 || true
  fi
}

while true; do
  if is_codex_running; then
    if ! is_pet_running; then
      start_pet
    fi
  else
    if is_pet_running; then
      stop_pet
    fi
  fi
  sleep 5
done
