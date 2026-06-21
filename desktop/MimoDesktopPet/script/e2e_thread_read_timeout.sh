#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_hanging_read_codex_app_server.py"
PRESENTATION_LOG="/tmp/mimo-thread-read-timeout-presentation-e2e.jsonl"
SCREENSHOT_PATH="/tmp/mimo-thread-read-timeout-e2e.png"
FAKE_LOG="/tmp/mimo-hanging-read-fake-codex.log"

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
rm -f "$PRESENTATION_LOG" "$SCREENSHOT_PATH" "$FAKE_LOG"

CODEX_BIN="$FAKE_CODEX" \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_APP_SERVER_REQUEST_TIMEOUT=1 \
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
deadline = time.time() + 10
connected_seen = False
timeout_seen = False
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

    last_rows = rows[-8:]
    for row in rows:
        if row.get("debugOverlay") is not False:
            raise SystemExit("thread-read-timeout E2E unexpectedly enabled debug overlay")
        bubbles = row.get("bubbleTexts", [])
        if not isinstance(bubbles, list):
            continue
        visible = " ".join(str(item) for item in bubbles)
        if row.get("isOffline") is False and "Timeout QA" in visible:
            connected_seen = True
        if connected_seen and row.get("isOffline") is True and "Codex 接続タイムアウト" in bubbles:
            timeout_seen = True
            print("Connected state and request-timeout offline presentation observed.")
            sys.exit(0)
    time.sleep(0.2)

print("thread-read-timeout E2E failed", file=sys.stderr)
print(f"connected_seen={connected_seen} timeout_seen={timeout_seen}", file=sys.stderr)
print(f"recent_rows={last_rows}", file=sys.stderr)
sys.exit(1)
PY

kill -0 "$APP_PID" >/dev/null
screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
swift ./script/inspect_production_capture.swift "$SCREENSHOT_PATH"

grep -Fq 'holding thread/read response' "$FAKE_LOG"

echo "E2E passed: hanging thread/read request times out into a transparent offline production bubble."
