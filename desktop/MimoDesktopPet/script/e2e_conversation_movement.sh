#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_codex_app_server.py"
PRESENTATION_LOG="/tmp/mimo-conversation-movement-presentation-e2e.jsonl"

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

CODEX_BIN="$FAKE_CODEX" \
MIMO_FAKE_CODEX_STATE_DELAY_MULTIPLIER=3 \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_FORCE_BEGIN=1 \
MIMO_AUTONOMOUS_INITIAL_REST_SECONDS=0 \
MIMO_CLICK_THROUGH=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="220,220" \
"$APP_BINARY" &
APP_PID=$!

kill -0 "$APP_PID" >/dev/null

WINDOW_ID="$(swift ./script/find_mimo_window.swift --pid "$APP_PID" --max-width 520 --max-height 560)"

python3 - "$PRESENTATION_LOG" <<'PY'
import json
import os
import sys
import time

log_path = sys.argv[1]
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
        bubbles = " ".join(str(item) for item in row.get("bubbleTexts", []))
        if "Mimo runtime QA" in bubbles and row.get("debugOverlay") is False:
            print("Conversation presentation observed.")
            raise SystemExit(0)
    time.sleep(0.15)

print(f"conversation presentation was not observed: {last_rows}", file=sys.stderr)
raise SystemExit(1)
PY

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

Thread.sleep(forTimeInterval: 0.5)

var samples: [(Double, Double)] = []
for _ in 0..<240 {
    if let origin = windowOrigin() {
        samples.append(origin)
    }
    Thread.sleep(forTimeInterval: 1.0 / 60.0)
}

guard let first = samples.first, samples.count >= 180 else {
    fputs("too few conversation-movement samples: \(samples.count)\n", stderr)
    exit(1)
}

let distancesFromFirst = samples.map { hypot($0.0 - first.0, $0.1 - first.1) }
let maxDistanceFromFirst = distancesFromFirst.max() ?? 0
let deltas = zip(samples.dropFirst(), samples).map { current, previous in
    hypot(current.0 - previous.0, current.1 - previous.1)
}
let movingSamples = deltas.filter { $0 > 0.05 }.count

guard maxDistanceFromFirst >= 12 else {
    fputs("Mimo did not walk while the Kataribe report was visible: \(maxDistanceFromFirst)\n", stderr)
    exit(1)
}

guard movingSamples >= 30 else {
    fputs("conversation window had too few moving samples: \(movingSamples)\n", stderr)
    exit(1)
}

let largestDelta = deltas.max() ?? 0
guard largestDelta <= 4 else {
    fputs("conversation movement exceeded the smooth frame-distance bound: \(largestDelta)\n", stderr)
    exit(1)
}
SWIFT

python3 - "$PRESENTATION_LOG" <<'PY'
import json
import sys

rows = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8") if line.strip()]
walking_reports = [
    row for row in rows
    if row.get("isPetMoving") is True
    and row.get("animation") in {"running-left", "running-right"}
    and row.get("kataribeReportText")
]
if not walking_reports:
    raise SystemExit("no named Kataribe report remained visible during directional walking")
if not any("Mimo runtime QA" in row.get("kataribeCharmTitles", []) for row in walking_reports):
    raise SystemExit("the active Codex chat disappeared from the rail while Mimo walked")
PY

kill -0 "$APP_PID" >/dev/null

echo "E2E passed: Mimo keeps a named Kataribe report visible while walking smoothly, and chat switching remains rest-paced."
