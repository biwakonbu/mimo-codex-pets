#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
PRESENTATION_LOG="/tmp/mimo-unavailable-presentation-e2e.jsonl"
SCREENSHOT_PATH="/tmp/mimo-unavailable-e2e.png"
MISSING_CODEX_BIN="/tmp/mimo-missing-codex-bin-$$"

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
rm -f "$PRESENTATION_LOG" "$SCREENSHOT_PATH" "$MISSING_CODEX_BIN"

CODEX_BIN="$MISSING_CODEX_BIN" \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_TEST_MODE=1 \
MIMO_AUTONOMOUS_DISABLED=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="160,160" \
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
deadline = time.time() + 8
last_error = "presentation log was not created"

while time.time() < deadline:
    if not os.path.exists(log_path):
        time.sleep(0.2)
        continue
    try:
        with open(log_path, "r", encoding="utf-8") as handle:
            rows = [json.loads(line) for line in handle if line.strip()]
    except (OSError, json.JSONDecodeError) as error:
        last_error = f"presentation log was not readable: {error}"
        time.sleep(0.2)
        continue

    for row in rows:
        if row.get("debugOverlay") is not False:
            raise SystemExit("unavailable app-server unexpectedly enabled debug overlay")
        bubbles = row.get("bubbleTexts", [])
        if not isinstance(bubbles, list):
            continue
        if row.get("isOffline") is True and "Codex 接続待ち" in bubbles:
            print("Offline presentation observed.")
            sys.exit(0)
    if rows:
        last_error = "offline presentation was not observed"
    time.sleep(0.2)

print(f"Unavailable app-server E2E failed: {last_error}", file=sys.stderr)
sys.exit(1)
PY

kill -0 "$APP_PID" >/dev/null
screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
swift ./script/inspect_production_capture.swift "$SCREENSHOT_PATH"

echo "E2E passed: unavailable Codex app-server keeps transparent production Mimo alive with an offline bubble."
