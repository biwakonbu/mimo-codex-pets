#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
PRESENTATION_LOG="/tmp/mimo-live-presentation-smoke.jsonl"
TIMEOUT_SECONDS="${MIMO_LIVE_PRESENTATION_TIMEOUT:-14}"

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
rm -f "$PRESENTATION_LOG"

MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
"$APP_BINARY" &
APP_PID=$!

kill -0 "$APP_PID" >/dev/null

python3 - "$PRESENTATION_LOG" "$TIMEOUT_SECONDS" <<'PY'
import json
import os
import sys
import time

log_path = sys.argv[1]
timeout = float(sys.argv[2])
deadline = time.time() + timeout
offline_seen = False
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
        bubble = str(row.get("bubbleText", ""))
        is_offline = bool(row.get("isOffline", False))
        if is_offline:
            offline_seen = True
        elif offline_seen and bubble and "接続" not in bubble and "未設定" not in bubble:
            print("Live app presentation smoke passed: app reached a connected presentation state.")
            sys.exit(0)

    if rows:
        last_error = "app did not leave offline/connection presentation state"
    time.sleep(0.2)

print(f"Live app presentation smoke failed: {last_error}", file=sys.stderr)
sys.exit(1)
PY
