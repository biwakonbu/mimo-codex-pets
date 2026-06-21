#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_codex_app_server.py"
FAKE_LOG="/tmp/mimo-hanging-daemon-fake-codex.log"
PRESENTATION_LOG="/tmp/mimo-hanging-daemon-presentation-e2e.jsonl"
SCREENSHOT_PATH="/tmp/mimo-hanging-daemon-e2e.png"

cleanup() {
  if [[ -n "${APP_PID:-}" ]] && kill -0 "$APP_PID" >/dev/null 2>&1; then
    kill "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi
  rm -f /tmp/mimo-fake-codex.log
}
trap cleanup EXIT

cd "$ROOT_DIR"
./script/build_and_run.sh --verify
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
rm -f "$FAKE_LOG" "$PRESENTATION_LOG" "$SCREENSHOT_PATH" /tmp/mimo-fake-codex.log

CODEX_BIN="$FAKE_CODEX" \
MIMO_FAKE_CODEX_HANG_DAEMON=1 \
MIMO_APP_SERVER_DAEMON_START_TIMEOUT=0.15 \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_DISABLED=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="170,170" \
"$APP_BINARY" &
APP_PID=$!

kill -0 "$APP_PID" >/dev/null

WINDOW_ID="$(swift ./script/find_mimo_window.swift --pid "$APP_PID" --max-width 440 --max-height 560)"

python3 - "$PRESENTATION_LOG" <<'PY'
import json
import os
import sys
import time

log_path = sys.argv[1]
deadline = time.time() + 12
last_error = "presentation log was not created"

while time.time() < deadline:
    if not os.path.exists(log_path):
        time.sleep(0.15)
        continue
    try:
        with open(log_path, "r", encoding="utf-8") as handle:
            rows = [json.loads(line) for line in handle if line.strip()]
    except (OSError, json.JSONDecodeError) as error:
        last_error = f"presentation log was not readable: {error}"
        time.sleep(0.15)
        continue

    for row in rows:
        if row.get("debugOverlay") is not False:
            raise SystemExit("hanging-daemon run unexpectedly enabled debug overlay")
        bubbles = row.get("bubbleTexts", [])
        roles = row.get("bubbleRoles", [])
        tones = row.get("bubbleTones", [])
        if not isinstance(bubbles, list):
            continue
        if roles and len(roles) != len(bubbles):
            raise SystemExit(f"bubble roles did not match text count: roles={roles} bubbles={bubbles}")
        if tones and len(tones) != len(bubbles):
            raise SystemExit(f"bubble tones did not match text count: tones={tones} bubbles={bubbles}")
        visible = " ".join(str(item) for item in bubbles)
        if row.get("isOffline") is False and "Mimo runtime QA" in visible:
            print("Hanging daemon start was skipped after timeout and stdio connection reached production bubbles.")
            sys.exit(0)
    if rows:
        last_error = f"connected production bubble was not observed; recent={rows[-3:]}"
    time.sleep(0.15)

print(f"Hanging daemon E2E failed: {last_error}", file=sys.stderr)
sys.exit(1)
PY

cp /tmp/mimo-fake-codex.log "$FAKE_LOG"
grep -Fq 'argv ["app-server", "daemon", "start"]' "$FAKE_LOG"
grep -Fq 'daemon hanging' "$FAKE_LOG"
grep -Fq 'argv ["app-server", "--stdio"]' "$FAKE_LOG"
grep -Eq '"method":"initialize"' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/read"' "$FAKE_LOG"

kill -0 "$APP_PID" >/dev/null
screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
swift ./script/inspect_production_capture.swift "$SCREENSHOT_PATH"

echo "E2E passed: a hanging daemon start is timed out, stdio app-server still connects, and production Mimo stays transparent."
