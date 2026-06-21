#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_empty_codex_app_server.py"
SCREENSHOT_PATH="/tmp/mimo-desktop-pet-empty-thread-list-e2e.png"
FAKE_LOG="/tmp/mimo-empty-fake-codex.log"
PRESENTATION_LOG="/tmp/mimo-presentation-empty-thread-list-e2e.jsonl"

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

MIMO_CODEX_EXECUTABLE="$FAKE_CODEX" \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_DISABLED=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="190,190" \
"$APP_BINARY" &
APP_PID=$!

kill -0 "$APP_PID" >/dev/null

WINDOW_ID="$(swift ./script/find_mimo_window.swift --pid "$APP_PID" --max-width 440 --max-height 440)"

python3 - "$PRESENTATION_LOG" <<'PY'
import json
import sys
import time

log_path = sys.argv[1]
deadline = time.time() + 8
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
            raise SystemExit("empty-list production run unexpectedly enabled debug overlay")
        if row.get("isOffline") is False and bubble_text == "待機中" and bubbles == ["待機中"]:
            print("Empty thread list presentation reached connected idle state.")
            raise SystemExit(0)
        if "接続待ち" in visible or "接続タイムアウト" in visible:
            last_error = f"empty connected server still looked offline: {visible!r}"
        else:
            last_error = f"latest visible text was {visible!r}, isOffline={row.get('isOffline')!r}"
    time.sleep(0.2)

raise SystemExit(last_error)
PY

swift ./script/inspect_accessibility_surface.swift \
  --pid "$APP_PID" \
  --value-contains "本番表示。" \
  --value-contains "待機中" \
  --child-description "Mimo" \
  --node-description-contains "MimoDesktopPet.productionSurface.bubble.0.status=待機中"

screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
swift ./script/inspect_production_capture.swift "$SCREENSHOT_PATH"

grep -Eq '"method":"thread\\?/loaded\\?/list"' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/list"' "$FAKE_LOG"
if grep -Eq '"method":"thread\\?/read"' "$FAKE_LOG"; then
  echo "empty thread list unexpectedly triggered thread/read" >&2
  exit 1
fi

echo "E2E passed: empty Codex thread list leaves production Mimo connected, transparent, and idle."
