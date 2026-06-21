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
MIMO_FAKE_CODEX_STATE_DELAY_MULTIPLIER=2 \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_DISABLED=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="180,180" \
"$APP_BINARY" &
APP_PID=$!

kill -0 "$APP_PID" >/dev/null

WINDOW_ID="$(swift ./script/find_mimo_window.swift --pid "$APP_PID" --max-width 440 --max-height 560)"

wait_for_presentation() {
  local label="$1"
  local animation="$2"
  local required_text="$3"
  local require_four_bubbles="$4"
  local required_tone="$5"

  python3 - "$PRESENTATION_LOG" "$label" "$animation" "$required_text" "$require_four_bubbles" "$required_tone" <<'PY'
import json
import os
import sys
import time

log_path, label, animation, required_text, require_four_bubbles, required_tone = sys.argv[1:]
deadline = time.time() + 18
last_rows = []
valid_tones = {"neutral", "active", "waiting", "review", "failed", "overflow"}
valid_activity_kinds = {
    "none",
    "message",
    "userRequest",
    "assistantMessage",
    "plan",
    "reasoning",
    "command",
    "test",
    "fileChange",
    "fileRead",
    "tool",
    "subAgent",
    "webSearch",
    "browser",
    "search",
    "image",
    "imageGeneration",
    "sleep",
    "review",
    "contextCompaction",
    "skill",
    "mention",
    "threadStatus",
}

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
    if not rows:
        time.sleep(0.15)
        continue
    for row in rows:
        if row.get("debugOverlay") is not False:
            raise SystemExit(f"{label}: production state unexpectedly enabled debug overlay")
        bubbles = row.get("bubbleTexts", [])
        roles = row.get("bubbleRoles", [])
        tones = row.get("bubbleTones", [])
        activity_kinds = row.get("bubbleActivityKinds", [])
        if not isinstance(bubbles, list):
            continue
        if len(bubbles) > 5:
            raise SystemExit(f"{label}: too many production bubbles: {bubbles}")
        if roles and len(roles) != len(bubbles):
            raise SystemExit(f"{label}: bubble roles did not match text count: roles={roles} bubbles={bubbles}")
        if not isinstance(tones, list) or len(tones) != len(bubbles):
            raise SystemExit(f"{label}: bubble tones did not match bubble text count: tones={tones} bubbles={bubbles}")
        if not isinstance(activity_kinds, list) or len(activity_kinds) != len(bubbles):
            raise SystemExit(f"{label}: bubble activity kinds did not match text count: activity_kinds={activity_kinds} bubbles={bubbles}")
        unknown_tones = [tone for tone in tones if tone not in valid_tones]
        if unknown_tones:
            raise SystemExit(f"{label}: bubble tones contained unknown values: {unknown_tones}")
        unknown_activity_kinds = [kind for kind in activity_kinds if kind not in valid_activity_kinds]
        if unknown_activity_kinds:
            raise SystemExit(f"{label}: bubble activity kinds contained unknown values: {unknown_activity_kinds}")

    row = rows[-1]
    bubbles = row.get("bubbleTexts", [])
    roles = row.get("bubbleRoles", [])
    tones = row.get("bubbleTones", [])
    activity_kinds = row.get("bubbleActivityKinds", [])
    if not isinstance(bubbles, list):
        time.sleep(0.15)
        continue

    joined = " ".join(str(item) for item in bubbles)
    if row.get("animation") != animation:
        time.sleep(0.15)
        continue
    if required_text not in joined:
        time.sleep(0.15)
        continue
    if required_tone and required_tone not in tones:
        time.sleep(0.15)
        continue
    if require_four_bubbles == "1":
        if len(bubbles) < 4:
            time.sleep(0.15)
            continue
        if roles[0] != "focus" or roles.count("conversation") < 3:
            raise SystemExit(f"{label}: unexpected multi-thread roles: {roles}")
        if any(kind == "none" for kind, role in zip(activity_kinds, roles) if role != "overflow"):
            raise SystemExit(f"{label}: multi-thread activity kinds were missing: {activity_kinds}")
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
  if [[ "$label" == "multi-thread" ]]; then
    local output=""
    for _ in {1..20}; do
      screencapture -x -o -l "$WINDOW_ID" "$path"
      if output="$(swift ./script/inspect_production_capture.swift --multi-bubble-hierarchy "$path" 2>&1)"; then
        printf '%s\n' "$output"
        return 0
      fi
      sleep 0.2
    done
    printf '%s\n' "$output" >&2
    return 1
  else
    screencapture -x -o -l "$WINDOW_ID" "$path"
    swift ./script/inspect_production_capture.swift "$path"
  fi
}

wait_for_presentation "active" "running" "Mimo runtime QA" "0" "active"
capture_and_inspect "active"

wait_for_presentation "waiting" "waiting" "確認を待" "0" "waiting"
capture_and_inspect "waiting"

wait_for_presentation "multi-thread" "waiting" "資料整理" "1" "active"
capture_and_inspect "multi-thread"

wait_for_presentation "review" "review" "確認できる" "0" "review"
capture_and_inspect "review"

wait_for_presentation "failed" "failed" "つまずき" "0" "failed"
capture_and_inspect "failed"

kill -0 "$APP_PID" >/dev/null

echo "E2E passed: production state matrix captured active, waiting, multi-thread, review, and failed Mimo bubble states in $CAPTURE_DIR."
