#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_codex_app_server.py"
SCREENSHOT_PATH="/tmp/mimo-desktop-pet-content-length-e2e.png"
FAKE_LOG="/tmp/mimo-fake-codex.log"
PRESENTATION_LOG="/tmp/mimo-presentation-content-length-e2e.jsonl"

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
rm -f "$FAKE_LOG" "$SCREENSHOT_PATH" "$PRESENTATION_LOG"

CODEX_BIN="$FAKE_CODEX" \
MIMO_FAKE_CODEX_FRAMING=content-length \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_DISABLED=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="180,180" \
"$APP_BINARY" &
APP_PID=$!

kill -0 "$APP_PID" >/dev/null

WINDOW_ID="$(swift ./script/find_mimo_window.swift --pid "$APP_PID" --max-width 440 --max-height 440)"

python3 - "$PRESENTATION_LOG" <<'PY'
import json
import sys
import time

log_path = sys.argv[1]
deadline = time.time() + 10
last_error = "presentation log did not appear"

while time.time() < deadline:
    try:
        with open(log_path, "r", encoding="utf-8") as handle:
            rows = [json.loads(line) for line in handle if line.strip()]
    except FileNotFoundError:
        time.sleep(0.2)
        continue

    for row in rows:
        bubble_text = str(row.get("bubbleText", ""))
        bubbles = [str(text) for text in row.get("bubbleTexts", [])]
        visible = " ".join([bubble_text] + bubbles)
        if row.get("debugOverlay") is not False:
            raise SystemExit("content-length production run unexpectedly enabled debug overlay")
        if row.get("isOffline") is False and "Mimo runtime QA" in visible:
            print("Content-Length presentation reached connected Mimo runtime QA state.")
            raise SystemExit(0)
        last_error = f"latest visible text was {visible!r}"
    time.sleep(0.2)

raise SystemExit(last_error)
PY

screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
swift ./script/inspect_production_capture.swift "$SCREENSHOT_PATH"

grep -Fq 'in-framing json-lines' "$FAKE_LOG"
grep -Fq 'in-framing content-length' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/loaded\\?/list"' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/read"' "$FAKE_LOG"

echo "E2E passed: content-length app-server framing connects, switches outgoing framing, and keeps production Mimo transparent."
