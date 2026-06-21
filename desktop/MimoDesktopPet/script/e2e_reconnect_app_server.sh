#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_recovering_codex_app_server.py"
PRESENTATION_LOG="/tmp/mimo-reconnect-presentation-e2e.jsonl"
SCREENSHOT_PATH="/tmp/mimo-reconnect-e2e.png"
FAKE_LOG="/tmp/mimo-recovering-fake-codex.log"
FAKE_STATE="/tmp/mimo-recovering-fake-codex-state.txt"

cleanup() {
  if [[ -n "${APP_PID:-}" ]] && kill -0 "$APP_PID" >/dev/null 2>&1; then
    kill "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

cd "$ROOT_DIR"
./script/build_and_run.sh --verify
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
rm -f "$PRESENTATION_LOG" "$SCREENSHOT_PATH" "$FAKE_LOG" "$FAKE_STATE"

CODEX_BIN="$FAKE_CODEX" \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_APP_SERVER_RECONNECT_DELAY=1 \
MIMO_AUTONOMOUS_DISABLED=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="175,175" \
"$APP_BINARY" &
APP_PID=$!

kill -0 "$APP_PID" >/dev/null

WINDOW_ID="$(swift ./script/find_mimo_window.swift --pid "$APP_PID" --max-width 440 --max-height 440)"

python3 - "$PRESENTATION_LOG" <<'PY'
import json
import os
import sys
import time

log_path = sys.argv[1]
deadline = time.time() + 14
initial_seen = False
offline_seen = False
recovered_seen = False
last_rows = []

while time.time() < deadline:
    if not os.path.exists(log_path):
        time.sleep(0.2)
        continue
    try:
        with open(log_path, "r", encoding="utf-8") as handle:
            rows = [json.loads(line) for line in handle if line.strip()]
    except (OSError, json.JSONDecodeError):
        time.sleep(0.2)
        continue

    last_rows = rows[-10:]
    for row in rows:
        if row.get("debugOverlay") is not False:
            raise SystemExit("reconnect E2E unexpectedly enabled debug overlay")
        bubbles = row.get("bubbleTexts", [])
        if not isinstance(bubbles, list):
            continue
        visible = " ".join(str(item) for item in bubbles)
        if row.get("isOffline") is False and "再接続前の確認" in visible:
            initial_seen = True
        if initial_seen and row.get("isOffline") is True and "Codex 接続切れ" in bubbles:
            offline_seen = True
        if offline_seen and row.get("isOffline") is False and "再接続後の確認" in visible:
            recovered_seen = True
            print("Initial, offline, and recovered connected presentations observed.")
            sys.exit(0)
    time.sleep(0.2)

print("reconnect E2E failed", file=sys.stderr)
print(
    f"initial_seen={initial_seen} offline_seen={offline_seen} recovered_seen={recovered_seen}",
    file=sys.stderr,
)
print(f"recent_rows={last_rows}", file=sys.stderr)
sys.exit(1)
PY

kill -0 "$APP_PID" >/dev/null
screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
swift ./script/inspect_production_capture.swift "$SCREENSHOT_PATH"

grep -Fq 'stdio start count=1' "$FAKE_LOG"
grep -Fq 'stdio start count=2' "$FAKE_LOG"
grep -Fq 'disconnecting first stdio' "$FAKE_LOG"
grep -Fq 'recovered stdio stayed available' "$FAKE_LOG"

echo "E2E passed: app-server disconnect recovers into a connected transparent production bubble without restarting Mimo."
