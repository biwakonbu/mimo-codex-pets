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

wait_for_kataribe_stage() {
  local timeout_seconds="${MIMO_E2E_PRESENTATION_TIMEOUT_SECONDS:-45}"
  python3 - "$PRESENTATION_LOG" "$timeout_seconds" <<'PY'
import json
import sys
import time
from pathlib import Path

log_path = Path(sys.argv[1])
timeout_seconds = float(sys.argv[2])
deadline = time.monotonic() + timeout_seconds
last_state = "presentation log did not appear"
while time.monotonic() < deadline:
    if not log_path.exists():
        time.sleep(0.25)
        continue
    try:
        rows = [json.loads(line) for line in log_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    except (OSError, json.JSONDecodeError):
        time.sleep(0.25)
        continue
    named_stage = any(
        {"Mimo runtime QA", "ステータスだけで進捗を伝える検証", "資料整理"}.issubset(
            set(row.get("kataribeCharmTitles", []))
        )
        for row in rows
    )
    generated_narration = any("Mimoもそっと見守ってるよ" in str(row.get("kataribeReportText", "")) for row in rows)
    walking_stage = any(
        row.get("isPetMoving") is True and row.get("animation") in {"running-left", "running-right"}
        for row in rows
    )
    closed_markers = {"別チャットの確認", "更新された別チャット"}
    closed_seen = any(closed_markers.intersection(row.get("kataribeCharmTitles", [])) for row in rows)
    closed_removed = closed_seen and not closed_markers.intersection(rows[-1].get("kataribeCharmTitles", []))
    started_seen = any("新しい実装チャット" in row.get("kataribeCharmTitles", []) for row in rows)
    if named_stage and generated_narration and walking_stage and closed_removed and started_seen:
        sys.exit(0)
    last_state = (
        f"named_stage={named_stage}, generated_narration={generated_narration}, "
        f"walking_stage={walking_stage}, closed_removed={closed_removed}, started_seen={started_seen}"
    )
    time.sleep(0.25)

raise SystemExit(f"Kataribe stage did not reach the expected live state before timeout: {last_state}")
PY
}

cd "$ROOT_DIR"
./script/build_and_run.sh --verify
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
rm -f "$FAKE_LOG" "$SCREENSHOT_PATH" "$PRESENTATION_LOG"

CODEX_BIN="$FAKE_CODEX" \
MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_AUTONOMOUS_TEST_MODE=1 \
MIMO_BUBBLE_TEST_MODE=1 \
MIMO_CODEX_DIALOGUE_ENABLED=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
MIMO_WINDOW_ORIGIN="160,160" \
"$APP_BINARY" &
APP_PID=$!

kill -0 "$APP_PID" >/dev/null

WINDOW_ID="$(swift ./script/find_mimo_window.swift --pid "$APP_PID" --max-width 520 --max-height 560)"

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

wait_for_kataribe_stage
kill -0 "$APP_PID" >/dev/null

grep -Fq 'Mimoもそっと見守ってるよ' "$PRESENTATION_LOG"
if grep -Fq 'Mimoも追いかけてるね' "$PRESENTATION_LOG"; then
  echo "technical tracking language leaked into Mimo narration" >&2
  exit 1
fi

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

stage_rows = [row for row in rows if row.get("kataribeCharmTitles")]
if not stage_rows:
    raise SystemExit("presentation log never showed the Kataribe chat rail")
if max(len(row.get("kataribeCharmTitles", [])) for row in stage_rows) < 4:
    raise SystemExit("Kataribe stage never retained four named chats")
if any(len(titles := row.get("kataribeCharmTitles", [])) != len(set(titles)) for row in stage_rows):
    raise SystemExit("Kataribe stage repeated a chat name")
if any(len(row.get("kataribeCharmTitles", [])) > 6 for row in stage_rows):
    raise SystemExit("Kataribe stage exceeded the six-chat identity rail")
if any("ほか" in title for row in stage_rows for title in row.get("kataribeCharmTitles", [])):
    raise SystemExit("Kataribe stage hid chat names behind an overflow label")
for row in stage_rows:
    titles = row.get("kataribeCharmTitles", [])
    thread_ids = row.get("kataribeCharmThreadIds", [])
    if not isinstance(thread_ids, list) or len(thread_ids) != len(titles):
        raise SystemExit(
            f"Kataribe stage charm identities did not match titles: ids={thread_ids!r} titles={titles!r}"
        )
    report_thread_id = row.get("kataribeReportThreadId")
    if report_thread_id not in (None, "none") and thread_ids and thread_ids[-1] != report_thread_id:
        raise SystemExit(
            "Kataribe stage did not keep the narrated chat at the bottom: "
            f"report={report_thread_id!r} ids={thread_ids!r}"
        )
if not any(row.get("isPetMoving") is True and row.get("kataribeReportText") for row in rows):
    raise SystemExit("Kataribe report was not retained while Mimo walked")
if not any(row.get("kataribeReportThreadId") in {"fake-status-only", "fake-started"} for row in rows):
    raise SystemExit("an action-required chat never interrupted the Kataribe report")
for row in stage_rows:
    accessibility_value = str(row.get("accessibilityValue", ""))
    for title in row.get("kataribeCharmTitles", []):
        if title not in accessibility_value:
            raise SystemExit(f"accessibility value omitted named chat {title!r}: {accessibility_value!r}")
    if any(raw in accessibility_value for raw in ("running-left", "running-right", "active", "Codex Thread")):
        raise SystemExit(f"accessibility value exposed an internal state: {accessibility_value!r}")

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
    if len(bubbles) > 4:
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
    if bubbles:
        primary_limit = 156
        if len(str(bubbles[0])) > primary_limit:
            raise SystemExit(f"primary production bubble is too long: {bubbles[0]}")
    for bubble, role in zip(bubbles[1:], roles[1:]):
        secondary_limit = 22 if role == "overflow" else 96
        if len(str(bubble)) > secondary_limit:
            raise SystemExit(f"secondary production bubble is too long: {bubble}")
    accessibility_value = str(row.get("accessibilityValue", ""))
    if bubbles and not accessibility_value:
        raise SystemExit("production presentation log omitted accessibilityValue")
    if bubbles and not accessibility_value.startswith("本番表示。"):
        raise SystemExit(f"production accessibility value did not mark production mode: {accessibility_value!r}")
    all_visible_text = " ".join(
        [str(row.get("bubbleText", "")), accessibility_value] +
        [str(bubble) for bubble in bubbles]
    )
    forbidden_fragments = (
        "swift test",
        "get_app_state",
        "raw assistant text",
        "secret-looking command output",
        "secret terminal input",
        "process-secret-id",
        "secret diff",
        "secret turn diff",
        "secret approval",
        "review-secret-id",
        "automatic-secret-source",
        "secret hook",
        "secret server request",
        "secret goal",
        "raw reasoning",
        "secret-model",
        "secret reason",
        "secret verification",
        "secret moderation",
        "secret warning",
        "secret guardian",
        "secret-mcp",
        "secret mcp",
        "secret error",
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
        "Mimo internal synthesis",
        "Mimo internal dialogue",
        "Return done.",
        "Observe the attached image",
    )
    for fragment in forbidden_fragments:
        if fragment in all_visible_text:
            raise SystemExit(f"production bubble leaked raw Codex activity text: {fragment!r} in {all_visible_text!r}")
    if (
        len(bubbles) >= 4
        and any("Mimo runtime QA" in str(text) for text in bubbles)
        and any("別チャットの確認" in str(text) for text in bubbles)
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

if not any(
    row.get("kataribeReportThreadId") in {"fake-status-only", "fake-started"}
    and any(marker in str(row.get("kataribeReportText", "")) for marker in ("返事を待", "確認を待", "つまず"))
    for row in rows
):
    raise SystemExit("action-required secondary chat was never promoted into the Kataribe report")

closed_thread_markers = ("別チャットの確認", "更新された別チャット")
tail_rows = rows[-1:]
if any(
    any(marker in str(text) for marker in closed_thread_markers)
    for row in tail_rows
    for text in row.get("kataribeCharmTitles", [])
):
    raise SystemExit("closed secondary chat remained in the recent Kataribe rail")

if not any(
    "新しい実装チャット" in row.get("kataribeCharmTitles", [])
    for row in rows
):
    raise SystemExit("notification-only started chat was never retained in the Kataribe rail")
PY

grep -Fq '"threadId":"fake-internal-ephemeral"' "$FAKE_LOG"
if grep -Eq 'Return done\.|Observe the attached image|Mimo internal' "$PRESENTATION_LOG"; then
  echo "ephemeral internal chat leaked into the visible presentation log" >&2
  exit 1
fi

sleep "${MIMO_CAPTURE_SETTLE_SECONDS:-1.8}"
screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
swift ./script/inspect_production_capture.swift --kataribe-stage "$SCREENSHOT_PATH"

grep -Fq 'argv ["app-server", "daemon", "start"]' "$FAKE_LOG"
grep -Fq 'argv ["app-server", "proxy"]' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/read"' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/list"' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/loaded\\?/list"' "$FAKE_LOG"
grep -Eq '"method":"thread\\?/start"' "$FAKE_LOG"
grep -Eq '"method":"turn\\?/start"' "$FAKE_LOG"
grep -Eq '"method":"item/commandExecution/terminalInteraction"' "$FAKE_LOG"
grep -Eq '"method":"item/fileChange/patchUpdated"' "$FAKE_LOG"
grep -Eq '"method":"turn/diff/updated"' "$FAKE_LOG"
grep -Eq '"method":"item/autoApprovalReview/started"' "$FAKE_LOG"
grep -Eq '"method":"item/autoApprovalReview/completed"' "$FAKE_LOG"
grep -Eq '"method":"hook/started"' "$FAKE_LOG"
grep -Eq '"method":"hook/completed"' "$FAKE_LOG"
grep -Eq '"method":"serverRequest/resolved"' "$FAKE_LOG"
grep -Eq '"method":"thread/goal/updated"' "$FAKE_LOG"
grep -Eq '"method":"thread/goal/cleared"' "$FAKE_LOG"
grep -Eq '"method":"thread/compacted"' "$FAKE_LOG"
grep -Eq '"method":"model/rerouted"' "$FAKE_LOG"
grep -Eq '"method":"model/verification"' "$FAKE_LOG"
grep -Eq '"method":"turn/moderationMetadata"' "$FAKE_LOG"
grep -Eq '"method":"warning"' "$FAKE_LOG"
grep -Eq '"method":"guardianWarning"' "$FAKE_LOG"
grep -Eq '"method":"mcpServer/startupStatus/updated"' "$FAKE_LOG"
grep -Eq '"method":"error"' "$FAKE_LOG"

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

dialogue_thread_starts = [
    message
    for direction, message in events
    if direction == "in"
    and message.get("method") == "thread/start"
    and message.get("params", {}).get("serviceName") == "mimo_desktop_pet"
]
if not dialogue_thread_starts:
    raise SystemExit("Mimo dialogue thread/start was not observed")
if any(message.get("params", {}).get("model") != "gpt-5.6-luna" for message in dialogue_thread_starts):
    raise SystemExit(f"Mimo dialogue did not use gpt-5.6-luna: {dialogue_thread_starts!r}")

dialogue_turn_starts = [
    message
    for direction, message in events
    if direction == "in"
    and message.get("method") == "turn/start"
    and message.get("params", {}).get("threadId") == "mimo-dialogue-thread"
]
if not dialogue_turn_starts:
    raise SystemExit("Mimo dialogue turn/start was not observed")
if any(message.get("params", {}).get("model") != "gpt-5.6-luna" for message in dialogue_turn_starts):
    raise SystemExit(f"Mimo dialogue turn did not use gpt-5.6-luna: {dialogue_turn_starts!r}")
if any(message.get("params", {}).get("effort") != "low" for message in dialogue_turn_starts):
    raise SystemExit(f"Mimo dialogue turn did not use low effort: {dialogue_turn_starts!r}")

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

echo "E2E passed: fake Codex app-server, notification-driven Kataribe narration, named chat rail, walking readability, transparent always-on-top window, and thread reads verified."
