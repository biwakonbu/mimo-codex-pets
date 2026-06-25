#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_empty_codex_app_server.py"
PRESENTATION_LOG="/tmp/mimo-autonomous-default-stationary-presentation-e2e.jsonl"

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

var samples: [(Double, Double)] = []
for _ in 0..<300 {
    if let origin = windowOrigin() {
        samples.append(origin)
    }
    Thread.sleep(forTimeInterval: 1.0 / 60.0)
}

guard let first = samples.first, samples.count >= 240 else {
    fputs("too few default-stationary samples: \(samples.count)\n", stderr)
    exit(1)
}

let distancesFromStart = samples.map { hypot($0.0 - first.0, $0.1 - first.1) }
let maxDistanceFromStart = distancesFromStart.max() ?? 0
let deltas = zip(samples.dropFirst(), samples).map { current, previous in
    hypot(current.0 - previous.0, current.1 - previous.1)
}
let movingSamples = deltas.filter { $0 > 0.02 }.count

guard maxDistanceFromStart <= 0.75 else {
    fputs("default production launch moved the window unexpectedly: \(maxDistanceFromStart)\n", stderr)
    exit(1)
}

guard movingSamples == 0 else {
    fputs("default production launch had moving samples: \(movingSamples)\n", stderr)
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
        raise SystemExit("default stationary run unexpectedly enabled debug overlay")
    if any(row.get("isOffline") is False for row in rows):
        print("Default stationary presentation reached connected production mode.")
        raise SystemExit(0)
    time.sleep(0.2)

raise SystemExit("default stationary run did not reach connected production presentation")
PY

kill -0 "$APP_PID" >/dev/null

echo "E2E passed: default production launch keeps Mimo anchored unless autonomous window movement is explicitly enabled."
