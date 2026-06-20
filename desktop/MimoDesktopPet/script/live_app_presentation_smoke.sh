#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
PRESENTATION_LOG="/tmp/mimo-live-presentation-smoke.jsonl"
SCREENSHOT_PATH="/tmp/mimo-live-presentation-smoke.png"
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
rm -f "$PRESENTATION_LOG" "$SCREENSHOT_PATH"

MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
"$APP_BINARY" &
APP_PID=$!

kill -0 "$APP_PID" >/dev/null

WINDOW_ID="$(swift - <<'SWIFT'
import AppKit
import CoreGraphics
import Foundation

let expectedLayer = Int(CGWindowLevelForKey(.screenSaverWindow))
let deadline = Date().addingTimeInterval(8)
while Date() < deadline {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    if let window = windows.first(where: { ($0[kCGWindowOwnerName as String] as? String ?? "") == "MimoDesktopPet" }),
       let id = window[kCGWindowNumber as String],
       let layer = window[kCGWindowLayer as String] as? Int,
       let bounds = window[kCGWindowBounds as String] as? [String: Any],
       let width = bounds["Width"] as? Double,
       let height = bounds["Height"] as? Double {
        guard layer == expectedLayer else {
            fputs("unexpected Mimo window layer \(layer), expected screen-saver layer \(expectedLayer)\n", stderr)
            exit(1)
        }
        guard width <= 440, height <= 440 else {
            fputs("unexpected production window bounds \(width)x\(height)\n", stderr)
            exit(1)
        }
        print(id)
        exit(0)
    }
    Thread.sleep(forTimeInterval: 0.25)
}
exit(1)
SWIFT
)"

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
        if row.get("debugOverlay") is not False:
            raise SystemExit("live app presentation unexpectedly enabled debug overlay")
        bubbles = row.get("bubbleTexts", [])
        roles = row.get("bubbleRoles", [])
        if isinstance(bubbles, list):
            if len(bubbles) > 4:
                raise SystemExit(f"live app presentation showed too many bubbles: {bubbles}")
            if roles and len(roles) != len(bubbles):
                raise SystemExit(f"live app bubble roles did not match bubble text count: roles={roles} bubbles={bubbles}")
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

kill -0 "$APP_PID" >/dev/null
screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
swift ./script/inspect_production_capture.swift "$SCREENSHOT_PATH"
