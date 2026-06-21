#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_empty_codex_app_server.py"
LOCK_PATH="/tmp/mimo-desktop-pet-single-instance-e2e.lock"
FIRST_LOG="/tmp/mimo-single-instance-first.jsonl"
SECOND_LOG="/tmp/mimo-single-instance-second.jsonl"
SECOND_STDERR="/tmp/mimo-single-instance-second.stderr"

cleanup() {
  if [[ -n "${SECOND_PID:-}" ]] && kill -0 "$SECOND_PID" >/dev/null 2>&1; then
    kill "$SECOND_PID" >/dev/null 2>&1 || true
    wait "$SECOND_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "${APP_PID:-}" ]] && kill -0 "$APP_PID" >/dev/null 2>&1; then
    kill "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  rm -f "$LOCK_PATH"
}
trap cleanup EXIT

cd "$ROOT_DIR"
./script/build_and_run.sh --verify
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
rm -f "$LOCK_PATH" "$FIRST_LOG" "$SECOND_LOG" "$SECOND_STDERR"

CODEX_BIN="$FAKE_CODEX" \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_DISABLED=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_SINGLE_INSTANCE_LOCK_PATH="$LOCK_PATH" \
MIMO_PRESENTATION_LOG="$FIRST_LOG" \
MIMO_WINDOW_ORIGIN="210,210" \
"$APP_BINARY" &
APP_PID=$!

python3 - "$FIRST_LOG" <<'PY'
import json
import os
import sys
import time

log_path = sys.argv[1]
deadline = time.time() + 8

while time.time() < deadline:
    if not os.path.exists(log_path):
        time.sleep(0.15)
        continue
    with open(log_path, "r", encoding="utf-8") as handle:
        rows = [json.loads(line) for line in handle if line.strip()]
    if any(row.get("isOffline") is False for row in rows):
        raise SystemExit(0)
    time.sleep(0.15)

raise SystemExit("first Mimo instance did not reach a connected presentation state")
PY

CODEX_BIN="$FAKE_CODEX" \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_DISABLED=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_SINGLE_INSTANCE_LOCK_PATH="$LOCK_PATH" \
MIMO_PRESENTATION_LOG="$SECOND_LOG" \
MIMO_WINDOW_ORIGIN="760,210" \
"$APP_BINARY" 2>"$SECOND_STDERR" &
SECOND_PID=$!

deadline=$((SECONDS + 5))
while kill -0 "$SECOND_PID" >/dev/null 2>&1; do
  if (( SECONDS >= deadline )); then
    echo "second Mimo instance remained running instead of exiting" >&2
    exit 1
  fi
  sleep 0.1
done
wait "$SECOND_PID"
SECOND_PID=""

grep -Fq "already running" "$SECOND_STDERR"

pids="$(pgrep -x "$APP_NAME" || true)"
pid_count="$(printf '%s\n' "$pids" | sed '/^$/d' | wc -l | tr -d ' ')"
if [[ "$pid_count" != "1" || "$pids" != "$APP_PID" ]]; then
  printf 'expected exactly the first Mimo process to remain; got pids=%s first=%s\n' "${pids:-<none>}" "$APP_PID" >&2
  exit 1
fi

WINDOW_COUNT="$(swift - "$APP_PID" <<'SWIFT'
import CoreGraphics
import Foundation

let expectedPID = Int(CommandLine.arguments[1]) ?? -1
let expectedLayer = Int(CGWindowLevelForKey(.screenSaverWindow))
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let mimoWindows = windows.filter { window in
    (window[kCGWindowOwnerName as String] as? String ?? "") == "MimoDesktopPet"
        && (window[kCGWindowLayer as String] as? Int) == expectedLayer
}
let wrongPIDWindows = mimoWindows.filter { window in
    (window[kCGWindowOwnerPID as String] as? Int) != expectedPID
}
if !wrongPIDWindows.isEmpty {
    fputs("found Mimo windows not owned by first process: \(wrongPIDWindows)\n", stderr)
    exit(1)
}
print(mimoWindows.count)
SWIFT
)"

if [[ "$WINDOW_COUNT" != "1" ]]; then
  echo "expected one screen-saver-level Mimo window, got $WINDOW_COUNT" >&2
  exit 1
fi

if [[ -s "$SECOND_LOG" ]]; then
  echo "second Mimo instance unexpectedly initialized presentation logging" >&2
  exit 1
fi

echo "E2E passed: duplicate Mimo launch exits before creating a second desktop pet window."
