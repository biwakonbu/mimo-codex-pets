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
MIMO_CONVERSATION_BUBBLE_DURATION_OVERRIDE=30.0 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="200,200" \
"$APP_BINARY" &
APP_PID=$!

kill -0 "$APP_PID" >/dev/null

WINDOW_ID="$(swift ./script/find_mimo_window.swift --pid "$APP_PID" --max-width 520 --max-height 560)"

python3 - "$PRESENTATION_LOG" <<'PY'
import json
import sys
import time

log_path = sys.argv[1]
deadline = time.time() + 10
last_error = "presentation log did not appear"
expected_titles = ["実装確認", "UI 調整", "テスト追加", "資料整理", "リリース準備", "主作業"]

while time.time() < deadline:
    try:
        with open(log_path, "r", encoding="utf-8") as handle:
            rows = [json.loads(line) for line in handle if line.strip()]
    except FileNotFoundError:
        time.sleep(0.2)
        continue

    for row in rows:
        titles = row.get("kataribeCharmTitles", [])
        report = str(row.get("kataribeReportText", ""))
        if row.get("debugOverlay") is not False:
            raise SystemExit("overflow production run unexpectedly enabled debug overlay")
        if row.get("isOffline") is not False:
            last_error = f"latest row was offline: {report!r}"
            continue
        if titles != expected_titles:
            last_error = f"expected six bottom-up feed charms, got {titles!r}"
            continue
        if row.get("kataribeReportThreadId") != "overflow-1":
            last_error = f"expected primary report to target overflow-1, got {row.get('kataribeReportThreadId')!r}"
            continue
        if "主作業" not in report:
            last_error = f"primary report did not name its chat: {report!r}"
            continue
        if "ほか" in report or any("ほか" in title for title in titles):
            raise SystemExit(f"Kataribe stage hid chat names behind an overflow summary: report={report!r} titles={titles!r}")
        print("Kataribe stage reached a complete six-chat identity rail.")
        raise SystemExit(0)
    time.sleep(0.2)

raise SystemExit(last_error)
PY

swift ./script/inspect_accessibility_surface.swift \
  --pid "$APP_PID" \
  --value-contains "Mimoの報告。主作業" \
  --value-contains "リリース準備" \
  --child-description "Mimo" \
  --node-identifier "mimo.kataribe.report" \
  --node-identifier "mimo.kataribe.charm.0" \
  --node-identifier "mimo.kataribe.charm.1" \
  --node-identifier "mimo.kataribe.charm.2" \
  --node-identifier "mimo.kataribe.charm.3" \
  --node-identifier "mimo.kataribe.charm.4" \
  --node-identifier "mimo.kataribe.charm.5" \
  --node-description-contains "mimo.kataribe.report=主作業" \
  --node-description-contains "mimo.kataribe.charm.5=主作業" \
  --forbid-identifier "MimoDesktopPet.productionSurface.bubble.debug.status" \
  --forbid-description-contains "Mimo speech bubble:" \
  --forbid-description-contains "Codex の会話を待っています" \
  --forbid-value-contains "ほか" \
  --forbid-value-contains "Codex Thread" \
  --forbid-value-contains "デバッグ表示"

sleep "${MIMO_CAPTURE_SETTLE_SECONDS:-3.2}"
capture_output=""
for _ in {1..20}; do
  screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
  if capture_output="$(swift ./script/inspect_production_capture.swift --kataribe-stage --minimum-chat-charms 6 "$SCREENSHOT_PATH" 2>&1)"; then
    printf '%s\n' "$capture_output"
    break
  fi
  sleep 0.2
done
if [[ -z "$capture_output" ]] || ! grep -q "Kataribe stage inspection passed" <<<"$capture_output"; then
  printf '%s\n' "$capture_output" >&2
  exit 1
fi

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

echo "E2E passed: six Codex chats remain named, readable, clickable, and visible in the Kataribe stage without an overflow summary."
