#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_codex_app_server.py"
SCREENSHOT_PATH="/tmp/mimo-desktop-pet-e2e.png"
FAKE_LOG="/tmp/mimo-fake-codex.log"
PRESENTATION_LOG="/tmp/mimo-presentation-e2e.jsonl"

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
MIMO_AUTONOMOUS_TEST_MODE=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="160,160" \
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

swift - "$WINDOW_ID" <<'SWIFT'
import CoreGraphics
import Foundation

let windowNumber = CGWindowID(Int(CommandLine.arguments[1]) ?? 0)

func windowX() -> Double? {
    guard
        let windows = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowNumber) as? [[String: Any]],
        let bounds = windows.first?[kCGWindowBounds as String] as? [String: Any],
        let x = bounds["X"] as? Double
    else {
        return nil
    }
    return x
}

var samples: [Double] = []
for _ in 0..<210 {
    if let x = windowX() {
        samples.append(x)
    }
    Thread.sleep(forTimeInterval: 1.0 / 60.0)
}

guard samples.count >= 90 else {
    fputs("too few movement samples: \(samples.count)\n", stderr)
    exit(1)
}

let deltas = zip(samples.dropFirst(), samples).map { $0 - $1 }
let movedDistance = abs((samples.last ?? 0) - (samples.first ?? 0))
let movingDeltas = deltas.map(abs).filter { $0 > 0.05 }
let largestDelta = deltas.map(abs).max() ?? 0
let deltaChanges = zip(deltas.dropFirst(), deltas).map { abs($0 - $1) }
let largestDeltaChange = deltaChanges.max() ?? 0

guard movedDistance >= 40 else {
    fputs("autonomous movement did not travel far enough: \(movedDistance)\n", stderr)
    exit(1)
}
guard movingDeltas.count >= 30 else {
    fputs("autonomous movement had too few moving samples: \(movingDeltas.count)\n", stderr)
    exit(1)
}
guard largestDelta <= 14 else {
    fputs("autonomous movement jumped too far in one sample: \(largestDelta)\n", stderr)
    exit(1)
}
guard largestDeltaChange <= 14 else {
    fputs("autonomous movement delta changed too abruptly: \(largestDeltaChange)\n", stderr)
    exit(1)
}
SWIFT

sleep 10
kill -0 "$APP_PID" >/dev/null

grep -Fq 'ご主人、「Mimo runtime QA」は作業を進めています' "$PRESENTATION_LOG"
grep -Fq 'ご主人、「Mimo runtime QA」はツールで確認中です' "$PRESENTATION_LOG"
grep -Fq 'ご主人、「Mimo runtime QA」は応答をまとめています' "$PRESENTATION_LOG"
grep -Fq 'ご主人、「Mimo runtime QA」は計画を整理中です' "$PRESENTATION_LOG"
grep -Fq 'ご主人、「Mimo runtime QA」は文脈を整理中です' "$PRESENTATION_LOG"
grep -Fq 'ご主人、「Mimo runtime QA」はコマンドを実行中です' "$PRESENTATION_LOG"
grep -Fq 'ご主人、「Mimo runtime QA」は確認待ちです' "$PRESENTATION_LOG"
grep -Fq 'ご主人、「別スレッドの確認」はレビューできます' "$PRESENTATION_LOG"
grep -Fq '「別スレッドの確認」作業中' "$PRESENTATION_LOG"
grep -Fq '「更新された別スレッド」作業中' "$PRESENTATION_LOG"
grep -Fq 'ご主人、「ステータスだけで進捗を伝える検証」は確認待ちです' "$PRESENTATION_LOG"
grep -Fq 'ご主人、「資料整理」は作業を進めています' "$PRESENTATION_LOG"
grep -Fq '新しい実装スレッド' "$PRESENTATION_LOG"

python3 - "$PRESENTATION_LOG" <<'PY'
import json
import re
import sys

log_path = sys.argv[1]
rows = []
with open(log_path, "r", encoding="utf-8") as handle:
    for line in handle:
        if line.strip():
            rows.append(json.loads(line))

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

for row in rows:
    if row.get("debugOverlay") is not False:
        raise SystemExit("production presentation log unexpectedly enabled debug overlay")
    bubbles = row.get("bubbleTexts", [])
    roles = row.get("bubbleRoles", [])
    tones = row.get("bubbleTones", [])
    activity_kinds = row.get("bubbleActivityKinds", [])
    if not isinstance(bubbles, list):
        continue
    if len(bubbles) > 5:
        raise SystemExit(f"production bubble stack showed too many bubbles: {len(bubbles)}")
    if roles and len(roles) != len(bubbles):
        raise SystemExit(f"production bubble roles did not match bubble text count: roles={roles} bubbles={bubbles}")
    if not isinstance(tones, list) or len(tones) != len(bubbles):
        raise SystemExit(f"production bubble tones did not match bubble text count: tones={tones} bubbles={bubbles}")
    if not isinstance(activity_kinds, list) or len(activity_kinds) != len(bubbles):
        raise SystemExit(f"production bubble activity kinds did not match bubble text count: activity_kinds={activity_kinds} bubbles={bubbles}")
    unknown_tones = [tone for tone in tones if tone not in {"neutral", "active", "waiting", "review", "failed", "overflow"}]
    if unknown_tones:
        raise SystemExit(f"production bubble tones contained unknown values: {unknown_tones}")
    unknown_activity_kinds = [kind for kind in activity_kinds if kind not in valid_activity_kinds]
    if unknown_activity_kinds:
        raise SystemExit(f"production bubble activity kinds contained unknown values: {unknown_activity_kinds}")
    thread_titles = []
    for bubble in bubbles:
        match = re.search(r"「([^」]+)」", str(bubble))
        if match:
            thread_titles.append(match.group(1))
    if len(thread_titles) != len(set(thread_titles)):
        raise SystemExit(f"production bubble stack repeated a thread title: {bubbles}")
    if bubbles and len(str(bubbles[0])) > 44:
        raise SystemExit(f"primary production bubble is too long: {bubbles[0]}")
    for bubble in bubbles[1:]:
        if len(str(bubble)) > 34:
            raise SystemExit(f"secondary production bubble is too long: {bubble}")
    all_visible_text = " ".join([str(row.get("bubbleText", ""))] + [str(bubble) for bubble in bubbles])
    forbidden_fragments = (
        "swift test",
        "get_app_state",
        "raw assistant text",
        "secret-looking command output",
        "raw reasoning",
        "Authorization",
        "Bearer",
        "password=secret",
        "private/project/.env",
        "/Users/example",
        ".env",
        "secret token",
        "TOKEN=short",
        "OPENAI_API_KEY",
        "Ignore previous instructions",
        "developer message",
    )
    for fragment in forbidden_fragments:
        if fragment in all_visible_text:
            raise SystemExit(f"production bubble leaked raw Codex activity text: {fragment!r} in {all_visible_text!r}")
    if (
        len(bubbles) >= 4
        and any("Mimo runtime QA" in str(text) for text in bubbles)
        and any("別スレッドの確認" in str(text) for text in bubbles)
        and any("ステータスだけで進捗を伝" in str(text) for text in bubbles)
        and any("資料整理" in str(text) for text in bubbles)
    ):
        if roles[0] != "focus" or roles.count("conversation") < 3:
            raise SystemExit(f"multi-thread bubble stack had unexpected roles: {roles}")
        if "waiting" not in tones or "active" not in tones:
            raise SystemExit(f"multi-thread bubble stack did not expose mixed semantic tones: {tones}")
        if any(kind == "none" for kind, role in zip(activity_kinds, roles) if role != "overflow"):
            raise SystemExit(f"multi-thread bubble stack lost activity-kind markers: {activity_kinds}")
        break
else:
    raise SystemExit("presentation log never showed three thread bubbles at once")

action_required_primary_seen = False
for row in rows:
    bubbles = row.get("bubbleTexts", [])
    roles = row.get("bubbleRoles", [])
    tones = row.get("bubbleTones", [])
    if not bubbles or not roles or not tones:
        continue
    if (
        roles[0] == "focus"
        and tones[0] in {"waiting", "review", "failed"}
        and any(
            marker in str(bubbles[0])
            for marker in ("ステータスだけで進捗を伝", "別スレッドの確認", "新しい実装スレッド")
        )
        and any("Mimo runtime" in str(text) for text in bubbles[1:])
    ):
        action_required_primary_seen = True
        break

if not action_required_primary_seen:
    raise SystemExit("action-required secondary thread was never promoted into the primary Mimo report")

closed_thread_markers = ("別スレッドの確認", "更新された別スレッド")
tail_rows = rows[-5:]
if any(
    any(marker in str(text) for marker in closed_thread_markers)
    for row in tail_rows
    for text in row.get("bubbleTexts", [])
):
    raise SystemExit("closed secondary thread remained in recent production bubbles")

if not any(
    any("新しい実装スレッド" in str(text) for text in row.get("bubbleTexts", []))
    for row in tail_rows
):
    raise SystemExit("notification-only started thread was not retained across later production bubble refreshes")
PY

screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
swift ./script/inspect_production_capture.swift "$SCREENSHOT_PATH"

grep -Fq 'argv ["app-server", "daemon", "start"]' "$FAKE_LOG"
grep -Fq 'argv ["app-server", "proxy"]' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/read"' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/list"' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/loaded\\?/list"' "$FAKE_LOG"

python3 - "$FAKE_LOG" <<'PY'
import json
import sys

log_path = sys.argv[1]
events = []
with open(log_path, "r", encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if not line.startswith(("in ", "out ")):
            continue
        direction, payload = line.split(" ", 1)
        try:
            message = json.loads(payload)
        except json.JSONDecodeError:
            continue
        events.append((direction, message))

notification_index = next(
    (
        index
        for index, (direction, message) in enumerate(events)
        if direction == "out"
        and message.get("method") == "thread/status/changed"
        and message.get("params", {}).get("threadId") == "fake-review"
    ),
    None,
)
if notification_index is None:
    raise SystemExit("fake-review status notification was not emitted")

read_index = next(
    (
        index
        for index, (direction, message) in enumerate(events[notification_index + 1 :], notification_index + 1)
        if direction == "in"
        and message.get("method") == "thread/read"
        and message.get("params", {}).get("threadId") == "fake-review"
    ),
    None,
)
if read_index is None:
    raise SystemExit("fake-review notification did not trigger thread/read")

next_poll_index = next(
    (
        index
        for index, (direction, message) in enumerate(events[notification_index + 1 :], notification_index + 1)
        if direction == "in" and message.get("method") == "thread/loaded/list"
    ),
    None,
)
if next_poll_index is not None and read_index > next_poll_index:
    raise SystemExit("fake-review thread/read waited for the next poll")

started_index = next(
    (
        index
        for index, (direction, message) in enumerate(events)
        if direction == "out"
        and message.get("method") == "thread/started"
        and message.get("params", {}).get("thread", {}).get("id") == "fake-started"
    ),
    None,
)
if started_index is None:
    raise SystemExit("fake-started thread notification was not emitted")

started_read_index = next(
    (
        index
        for index, (direction, message) in enumerate(events[started_index + 1 :], started_index + 1)
        if direction == "in"
        and message.get("method") == "thread/read"
        and message.get("params", {}).get("threadId") == "fake-started"
    ),
    None,
)
if started_read_index is None:
    raise SystemExit("fake-started thread notification did not trigger thread/read")

started_next_poll_index = next(
    (
        index
        for index, (direction, message) in enumerate(events[started_index + 1 :], started_index + 1)
        if direction == "in" and message.get("method") == "thread/loaded/list"
    ),
    None,
)
if started_next_poll_index is not None and started_read_index > started_next_poll_index:
    raise SystemExit("fake-started thread/read waited for the next poll")

close_index = next(
    (
        index
        for index, (direction, message) in enumerate(events)
        if direction == "out"
        and message.get("method") == "thread/closed"
        and message.get("params", {}).get("threadId") == "fake-review"
    ),
    None,
)
if close_index is None:
    raise SystemExit("fake-review close notification was not emitted")

status_only_index = next(
    (
        index
        for index, (direction, message) in enumerate(events)
        if direction == "out"
        and message.get("method") == "thread/status/changed"
        and message.get("params", {}).get("threadId") == "fake-status-only"
    ),
    None,
)
if status_only_index is None:
    raise SystemExit("status-only thread notification was not emitted")
PY

echo "E2E passed: fake Codex app-server, notification-driven multi-thread Mimo summary bubbles, smooth autonomous movement, always-on-top production window, transparent corners, and thread reads verified."
