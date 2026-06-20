#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_overflow_codex_app_server.py"
SCREENSHOT_PATH="/tmp/mimo-desktop-pet-overflow-thread-list-e2e.png"
FAKE_LOG="/tmp/mimo-overflow-fake-codex.log"
PRESENTATION_LOG="/tmp/mimo-presentation-overflow-thread-list-e2e.jsonl"

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
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_DISABLED=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="200,200" \
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
       let layer = window[kCGWindowLayer as String] as? Int {
        guard layer == expectedLayer else {
            fputs("unexpected Mimo window layer \(layer), expected screen-saver layer \(expectedLayer)\n", stderr)
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
import re
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
        bubbles = [str(text) for text in row.get("bubbleTexts", [])]
        roles = row.get("bubbleRoles", [])
        if row.get("debugOverlay") is not False:
            raise SystemExit("overflow production run unexpectedly enabled debug overlay")
        if row.get("isOffline") is not False:
            last_error = f"latest row was offline: {bubbles!r}"
            continue
        if len(bubbles) != 4:
            last_error = f"expected four production bubbles, got {bubbles!r}"
            continue
        if roles != ["status", "conversation", "conversation", "conversation"]:
            raise SystemExit(f"unexpected overflow bubble roles: roles={roles} bubbles={bubbles}")
        if "ほか3件も見ています" not in bubbles:
            last_error = f"overflow note missing from {bubbles!r}"
            continue
        thread_titles = [
            match.group(1)
            for bubble in bubbles
            for match in [re.search(r"「([^」]+)」", bubble)]
            if match
        ]
        if len(thread_titles) != len(set(thread_titles)):
            raise SystemExit(f"overflow bubble stack repeated a thread title: {bubbles}")
        print("Overflow thread-list presentation reached compact multi-thread state.")
        raise SystemExit(0)
    time.sleep(0.2)

raise SystemExit(last_error)
PY

screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
swift ./script/inspect_production_capture.swift --multi-bubble-hierarchy "$SCREENSHOT_PATH"

grep -Eq '"method":"thread\\?/loaded\\?/list"' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/list"' "$FAKE_LOG"
grep -Eq '"limit":6' "$FAKE_LOG"
python3 - "$FAKE_LOG" <<'PY'
import json
import sys

log_path = sys.argv[1]
read_thread_ids = set()
with open(log_path, "r", encoding="utf-8") as handle:
    for line in handle:
        if not line.startswith("in "):
            continue
        try:
            message = json.loads(line[3:])
        except json.JSONDecodeError:
            continue
        if message.get("method") == "thread/read":
            read_thread_ids.add(message.get("params", {}).get("threadId"))

missing = {"overflow-5", "overflow-6"} - read_thread_ids
if missing:
    raise SystemExit(f"overflow threads were not read: {sorted(missing)}")
PY

echo "E2E passed: overflow Codex thread list reads beyond the visible stack and shows a compact overflow bubble."
