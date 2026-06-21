#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_codex_app_server.py"
FAKE_LOG="/tmp/mimo-proxy-fallback-fake-codex.log"
PRESENTATION_LOG="/tmp/mimo-proxy-fallback-presentation-e2e.jsonl"
SCREENSHOT_PATH="/tmp/mimo-proxy-fallback-e2e.png"

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
MIMO_FAKE_CODEX_FAIL_PROXY=1 \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_DISABLED=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="180,180" \
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
            raise SystemExit("proxy-fallback run unexpectedly enabled debug overlay")
        visible = " ".join(str(item) for item in row.get("bubbleTexts", []))
        if row.get("isOffline") is False and "Mimo runtime QA" in visible:
            print("Proxy failed, direct stdio fallback reached production bubbles.")
            raise SystemExit(0)
    if rows:
        last_error = f"connected production bubble was not observed; recent={rows[-3:]}"
    time.sleep(0.15)

raise SystemExit(last_error)
PY

cp /tmp/mimo-fake-codex.log "$FAKE_LOG"
grep -Fq 'argv ["app-server", "daemon", "start"]' "$FAKE_LOG"
grep -Fq 'argv ["app-server", "proxy"]' "$FAKE_LOG"
grep -Fq 'proxy failing' "$FAKE_LOG"
grep -Fq 'argv ["app-server", "--stdio"]' "$FAKE_LOG"
grep -Eq '"method":"initialize"' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/read"' "$FAKE_LOG"

kill -0 "$APP_PID" >/dev/null
screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
swift ./script/inspect_production_capture.swift "$SCREENSHOT_PATH"

echo "E2E passed: app-server proxy failure falls back to direct stdio while production Mimo stays transparent."
