#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_disconnect_codex_app_server.py"
PRESENTATION_LOG="/tmp/mimo-disconnect-presentation-e2e.jsonl"
SCREENSHOT_PATH="/tmp/mimo-disconnect-e2e.png"
FAKE_LOG="/tmp/mimo-disconnect-fake-codex.log"

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
MIMO_AUTONOMOUS_TEST_MODE=1 \
MIMO_AUTONOMOUS_DISABLED=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="160,160" \
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

python3 - "$PRESENTATION_LOG" <<'PY'
import json
import os
import sys
import time

log_path = sys.argv[1]
deadline = time.time() + 10
connected_seen = False
offline_seen = False
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
            raise SystemExit("disconnect E2E unexpectedly enabled debug overlay")
        bubbles = row.get("bubbleTexts", [])
        if not isinstance(bubbles, list):
            continue
        text = " ".join(str(item) for item in bubbles)
        if row.get("isOffline") is False and "切断耐性の確認" in text:
            connected_seen = True
        if connected_seen and row.get("isOffline") is True and "Codex 接続切れ" in bubbles:
            offline_seen = True
            print("Connected state and disconnect offline presentation observed.")
            sys.exit(0)
    time.sleep(0.2)

print("disconnect E2E failed", file=sys.stderr)
print(f"connected_seen={connected_seen} offline_seen={offline_seen}", file=sys.stderr)
print(f"recent_rows={last_rows}", file=sys.stderr)
sys.exit(1)
PY

kill -0 "$APP_PID" >/dev/null
screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
swift ./script/inspect_production_capture.swift "$SCREENSHOT_PATH"

grep -Fq 'disconnecting stdio' "$FAKE_LOG"

echo "E2E passed: connected Codex app-server disconnects, Mimo stays alive, and offline bubble is shown."
