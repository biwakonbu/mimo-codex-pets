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

WINDOW_ID="$(swift ./script/find_mimo_window.swift --pid "$APP_PID" --max-width 440 --max-height 560)"

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
        activity_kinds = row.get("bubbleActivityKinds", [])
        if row.get("debugOverlay") is not False:
            raise SystemExit("overflow production run unexpectedly enabled debug overlay")
        if row.get("isOffline") is not False:
            last_error = f"latest row was offline: {bubbles!r}"
            continue
        if len(bubbles) != 5:
            last_error = f"expected five production bubbles, got {bubbles!r}"
            continue
        if roles != ["focus", "conversation", "conversation", "conversation", "overflow"]:
            last_error = f"expected overflow bubble role, got roles={roles} bubbles={bubbles}"
            continue
        if not isinstance(activity_kinds, list) or len(activity_kinds) != len(bubbles):
            last_error = f"activity kinds did not match overflow bubble count: activity_kinds={activity_kinds} bubbles={bubbles}"
            continue
        if activity_kinds[:4].count("none") > 0 or activity_kinds[4] != "none":
            last_error = f"overflow bubble stack had wrong activity-kind markers: {activity_kinds}"
            continue
        if "ほか2件も見ています" not in bubbles:
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

swift ./script/inspect_accessibility_surface.swift \
  --pid "$APP_PID" \
  --value-contains "本番表示。" \
  --value-contains "ほか2件も見ています" \
  --child-description "Mimo" \
  --node-identifier "MimoDesktopPet.productionSurface.bubble.0.focus" \
  --node-identifier "MimoDesktopPet.productionSurface.bubble.1.conversation" \
  --node-identifier "MimoDesktopPet.productionSurface.bubble.2.conversation" \
  --node-identifier "MimoDesktopPet.productionSurface.bubble.3.conversation" \
  --node-description-contains "MimoDesktopPet.productionSurface.bubble.0.focus=ご主人" \
  --node-description-contains "MimoDesktopPet.productionSurface.bubble.4.overflow=ほか2件も見ています" \
  --forbid-identifier "MimoDesktopPet.productionSurface.bubble.debug.status" \
  --forbid-description-contains "Mimo speech bubble:" \
  --forbid-description-contains "Codex の会話を待っています" \
  --forbid-value-contains "デバッグ表示" \
  --ordered-identifiers "MimoDesktopPet.productionSurface.bubble.0.focus,MimoDesktopPet.productionSurface.bubble.1.conversation,MimoDesktopPet.productionSurface.bubble.2.conversation,MimoDesktopPet.productionSurface.bubble.3.conversation,MimoDesktopPet.productionSurface.bubble.4.overflow"

screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
swift ./script/inspect_production_capture.swift --multi-bubble-hierarchy "$SCREENSHOT_PATH"

grep -Eq '"method":"thread\\?/loaded\\?/list"' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/list"' "$FAKE_LOG"
grep -Eq '"limit":6' "$FAKE_LOG"
python3 - "$FAKE_LOG" <<'PY'
import json
import sys

log_path = sys.argv[1]
messages = []
with open(log_path, "r", encoding="utf-8") as handle:
    for line in handle:
        if not line.startswith("in "):
            continue
        try:
            message = json.loads(line[3:])
        except json.JSONDecodeError:
            continue
        messages.append(message)

read_thread_ids = {
    message.get("params", {}).get("threadId")
    for message in messages
    if message.get("method") == "thread/read"
}
missing = {"overflow-5", "overflow-6"} - read_thread_ids
if missing:
    raise SystemExit(f"overflow threads were not read: {sorted(missing)}")

first_refresh_index = next(
    (
        index
        for index, message in enumerate(messages)
        if message.get("method") == "thread/loaded/list"
    ),
    None,
)
if first_refresh_index is None:
    raise SystemExit("initial thread/loaded/list request was not observed")

second_refresh_index = next(
    (
        index
        for index, message in enumerate(messages[first_refresh_index + 1 :], first_refresh_index + 1)
        if message.get("method") == "thread/loaded/list"
    ),
    len(messages),
)
initial_refresh_reads = [
    message.get("params", {}).get("threadId")
    for message in messages[first_refresh_index + 1 : second_refresh_index]
    if message.get("method") == "thread/read"
]
duplicates = sorted(
    thread_id
    for thread_id in set(initial_refresh_reads)
    if initial_refresh_reads.count(thread_id) > 1
)
if duplicates:
    raise SystemExit(f"initial refresh issued duplicate thread/read requests: {duplicates}")
expected = {f"overflow-{index}" for index in range(1, 7)}
if set(initial_refresh_reads) != expected:
    raise SystemExit(f"initial refresh reads did not match tracked overflow threads: {initial_refresh_reads}")
PY

echo "E2E passed: overflow Codex thread list reads beyond the visible stack and shows a compact overflow bubble."
