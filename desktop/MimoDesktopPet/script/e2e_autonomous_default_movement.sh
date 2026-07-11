#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_empty_codex_app_server.py"
PRESENTATION_LOG="/tmp/mimo-autonomous-default-movement-presentation-e2e.jsonl"

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
rm -f "$PRESENTATION_LOG" /tmp/mimo-empty-fake-codex.log

MIMO_CODEX_EXECUTABLE="$FAKE_CODEX" \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_INITIAL_REST_SECONDS=0 \
MIMO_AUTONOMOUS_FORCE_BEGIN=1 \
MIMO_CLICK_THROUGH=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="220,220" \
"$APP_BINARY" &
APP_PID=$!

kill -0 "$APP_PID" >/dev/null

WINDOW_ID="$(swift ./script/find_mimo_window.swift --pid "$APP_PID" --max-width 520 --max-height 560)"

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

// Let CoreGraphics replace the window-server registration origin with the panel's configured origin.
Thread.sleep(forTimeInterval: 0.5)

var samples: [(Double, Double)] = []
for _ in 0..<300 {
    if let origin = windowOrigin() {
        samples.append(origin)
    }
    Thread.sleep(forTimeInterval: 1.0 / 60.0)
}

guard let first = samples.first, samples.count >= 240 else {
    fputs("too few default-movement samples: \(samples.count)\n", stderr)
    exit(1)
}

let distancesFromStart = samples.map { hypot($0.0 - first.0, $0.1 - first.1) }
let maxDistanceFromStart = distancesFromStart.max() ?? 0
let deltas = zip(samples.dropFirst(), samples).map { current, previous in
    hypot(current.0 - previous.0, current.1 - previous.1)
}
let movingSamples = deltas.filter { $0 > 0.02 }.count

guard maxDistanceFromStart >= 12 else {
    fputs("default production launch did not wander: \(maxDistanceFromStart)\n", stderr)
    exit(1)
}

guard movingSamples >= 45 else {
    fputs("default production launch had too few moving samples: \(movingSamples)\n", stderr)
    exit(1)
}

let largestDelta = deltas.max() ?? 0
guard largestDelta <= 4 else {
    fputs("default production launch exceeded the smooth frame-distance bound: \(largestDelta)\n", stderr)
    exit(1)
}
SWIFT

python3 - "$PRESENTATION_LOG" <<'PY'
import json
import sys
import time

log_path = sys.argv[1]
deadline = time.time() + 8

while time.time() < deadline:
    try:
        with open(log_path, "r", encoding="utf-8") as handle:
            rows = [json.loads(line) for line in handle if line.strip()]
    except FileNotFoundError:
        time.sleep(0.2)
        continue

    if not rows:
        time.sleep(0.2)
        continue
    if any(row.get("debugOverlay") is not False for row in rows):
        raise SystemExit("default movement run unexpectedly enabled debug overlay")
    directional = [row for row in rows if row.get("animation") in {"running-left", "running-right"}]
    if directional and any(row.get("isOffline") is False for row in rows):
        print("Default movement presentation reached a directional animation in connected production mode.")
        raise SystemExit(0)
    time.sleep(0.2)

raise SystemExit("default movement run did not reach a directional connected production presentation")
PY

kill -0 "$APP_PID" >/dev/null

echo "E2E passed: default production launch lets Mimo wander smoothly and uses a directional movement animation."
