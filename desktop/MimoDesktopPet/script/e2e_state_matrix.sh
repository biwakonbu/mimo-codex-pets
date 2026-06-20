#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_codex_app_server.py"
PRESENTATION_LOG="/tmp/mimo-state-matrix-presentation-e2e.jsonl"
CAPTURE_DIR="/tmp/mimo-state-matrix-e2e"

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
rm -rf "$CAPTURE_DIR"
mkdir -p "$CAPTURE_DIR"

CODEX_BIN="$FAKE_CODEX" \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_DISABLED=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="180,180" \
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

wait_for_presentation() {
  local label="$1"
  local animation="$2"
  local required_text="$3"
  local require_four_bubbles="$4"

  python3 - "$PRESENTATION_LOG" "$label" "$animation" "$required_text" "$require_four_bubbles" <<'PY'
import json
import os
import sys
import time

log_path, label, animation, required_text, require_four_bubbles = sys.argv[1:]
deadline = time.time() + 18
last_rows = []

while time.time() < deadline:
    if not os.path.exists(log_path):
        time.sleep(0.15)
        continue
    try:
        with open(log_path, "r", encoding="utf-8") as handle:
            rows = [json.loads(line) for line in handle if line.strip()]
    except (OSError, json.JSONDecodeError):
        time.sleep(0.15)
        continue

    last_rows = rows[-8:]
    for row in rows:
        if row.get("debugOverlay") is not False:
            raise SystemExit(f"{label}: production state unexpectedly enabled debug overlay")
        bubbles = row.get("bubbleTexts", [])
        roles = row.get("bubbleRoles", [])
        if not isinstance(bubbles, list):
            continue
        if len(bubbles) > 4:
            raise SystemExit(f"{label}: too many production bubbles: {bubbles}")
        if roles and len(roles) != len(bubbles):
            raise SystemExit(f"{label}: bubble roles did not match text count: roles={roles} bubbles={bubbles}")
        joined = " ".join(str(item) for item in bubbles)
        if row.get("animation") != animation:
            continue
        if required_text not in joined:
            continue
        if require_four_bubbles == "1":
            if len(bubbles) != 4:
                continue
            if roles != ["focus", "conversation", "conversation", "conversation"]:
                raise SystemExit(f"{label}: unexpected four-bubble roles: {roles}")
        print(f"{label} presentation observed.")
        raise SystemExit(0)

print(f"{label}: presentation was not observed", file=sys.stderr)
print(f"recent_rows={last_rows}", file=sys.stderr)
raise SystemExit(1)
PY
}

capture_and_inspect() {
  local label="$1"
  local path="$CAPTURE_DIR/$label.png"
  screencapture -x -o -l "$WINDOW_ID" "$path"
  if [[ "$label" == "multi-thread" ]]; then
    swift ./script/inspect_production_capture.swift --multi-bubble-hierarchy "$path"
  else
    swift ./script/inspect_production_capture.swift "$path"
  fi
}

wait_for_presentation "active" "running" "Mimo runtime QA" "0"
capture_and_inspect "active"

wait_for_presentation "waiting" "waiting" "確認待ち" "0"
capture_and_inspect "waiting"

wait_for_presentation "multi-thread" "waiting" "資料整理" "1"
capture_and_inspect "multi-thread"

wait_for_presentation "review" "review" "レビューできます" "0"
capture_and_inspect "review"

wait_for_presentation "failed" "failed" "失敗" "0"
capture_and_inspect "failed"

kill -0 "$APP_PID" >/dev/null

echo "E2E passed: production state matrix captured active, waiting, multi-thread, review, and failed Mimo bubble states in $CAPTURE_DIR."
