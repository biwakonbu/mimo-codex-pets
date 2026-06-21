#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_empty_codex_app_server.py"
SCREENSHOT_PATH="/tmp/mimo-autonomous-energy-e2e.png"
PRESENTATION_LOG="/tmp/mimo-autonomous-energy-presentation-e2e.jsonl"

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
rm -f "$SCREENSHOT_PATH" "$PRESENTATION_LOG" /tmp/mimo-empty-fake-codex.log

MIMO_CODEX_EXECUTABLE="$FAKE_CODEX" \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_ENERGY_TEST_MODE=1 \
MIMO_AUTONOMOUS_STAMINA_INITIAL=0.95 \
MIMO_AUTONOMOUS_STAMINA_DRAIN_PER_SECOND=0.9 \
MIMO_AUTONOMOUS_STAMINA_RECOVERY_PER_SECOND=1.5 \
MIMO_AUTONOMOUS_INITIAL_REST_SECONDS=0 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="220,220" \
"$APP_BINARY" &
APP_PID=$!

kill -0 "$APP_PID" >/dev/null

WINDOW_ID="$(swift ./script/find_mimo_window.swift --pid "$APP_PID" --max-width 440 --max-height 560)"

swift - "$WINDOW_ID" <<'SWIFT'
import CoreGraphics
import Foundation

let windowNumber = CGWindowID(Int(CommandLine.arguments[1]) ?? 0)

func windowOrigin() -> (Double, Double)? {
    guard
        let windows = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowNumber) as? [[String: Any]],
        let bounds = windows.first?[kCGWindowBounds as String] as? [String: Any],
        let x = bounds["X"] as? Double,
        let y = bounds["Y"] as? Double
    else {
        return nil
    }
    return (x, y)
}

var samples: [(Double, Double)] = []
for _ in 0..<390 {
    if let origin = windowOrigin() {
        samples.append(origin)
    }
    Thread.sleep(forTimeInterval: 1.0 / 60.0)
}

guard samples.count >= 180 else {
    fputs("too few autonomous energy samples: \(samples.count)\n", stderr)
    exit(1)
}

let deltas = zip(samples.dropFirst(), samples).map { current, previous in
    hypot(current.0 - previous.0, current.1 - previous.1)
}
let largestDelta = deltas.max() ?? 0
let movingFlags = deltas.map { $0 > 0.05 }
let movingCount = movingFlags.filter { $0 }.count

guard movingCount >= 24 else {
    fputs("autonomous energy test never moved enough: movingCount=\(movingCount)\n", stderr)
    exit(1)
}
guard largestDelta <= 14 else {
    fputs("autonomous energy movement jumped too far in one frame: \(largestDelta)\n", stderr)
    exit(1)
}

var sawMovingBeforeRest = false
var consecutiveRestSamples = 0
var sawRestAfterMoving = false
for moving in movingFlags {
    if moving {
        sawMovingBeforeRest = true
        consecutiveRestSamples = 0
    } else if sawMovingBeforeRest {
        consecutiveRestSamples += 1
        if consecutiveRestSamples >= 18 {
            sawRestAfterMoving = true
            break
        }
    }
}

guard sawRestAfterMoving else {
    fputs("autonomous energy test did not pause after moving\n", stderr)
    exit(1)
}
SWIFT

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

    running_index = None
    for index, row in enumerate(rows):
        if row.get("debugOverlay") is not False:
            raise SystemExit("autonomous energy run unexpectedly enabled debug overlay")
        if str(row.get("animation", "")).startswith("running"):
            running_index = index
            break

    if running_index is None:
        last_error = f"no running animation yet: {rows[-4:]}"
        time.sleep(0.2)
        continue

    rest_rows = [
        row
        for row in rows[running_index + 1 :]
        if str(row.get("animation", "")) in {"idle", "waiting", "waving", "jumping", "review"}
    ]
    if rest_rows:
        print("Autonomous energy presentation reached movement followed by rest.")
        raise SystemExit(0)

    last_error = f"running was observed but no rest animation followed: {rows[running_index:]}"
    time.sleep(0.2)

raise SystemExit(last_error)
PY

screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
swift ./script/inspect_production_capture.swift "$SCREENSHOT_PATH"

echo "E2E passed: autonomous stamina drains during movement, pauses Mimo for rest, and keeps production surface transparent."
