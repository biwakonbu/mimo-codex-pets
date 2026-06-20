#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
PRESENTATION_LOG="/tmp/mimo-live-presentation-smoke.jsonl"
PREFLIGHT_SUMMARY="/tmp/mimo-live-app-server-smoke-summary.json"
SCREENSHOT_PATH="/tmp/mimo-live-presentation-smoke.png"
TIMEOUT_SECONDS="${MIMO_LIVE_PRESENTATION_TIMEOUT:-14}"
EXPECT_THREAD_CONTEXT="${MIMO_LIVE_PRESENTATION_EXPECT_THREAD_CONTEXT:-auto}"

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
rm -f "$PRESENTATION_LOG" "$PREFLIGHT_SUMMARY" "$SCREENSHOT_PATH"

if [[ "$EXPECT_THREAD_CONTEXT" == "auto" ]]; then
  PREFLIGHT_OUTPUT=""
  PREFLIGHT_STATUS=1
  for attempt in 1 2 3; do
    rm -f "$PREFLIGHT_SUMMARY"
    if PREFLIGHT_OUTPUT="$(./script/live_app_server_smoke.py --summary-json "$PREFLIGHT_SUMMARY" 2>&1)"; then
      PREFLIGHT_STATUS=0
      break
    fi
    printf 'Live app presentation preflight attempt %s failed: %s\n' "$attempt" "$PREFLIGHT_OUTPUT" >&2
    sleep 1
  done

  if [[ "$PREFLIGHT_STATUS" -ne 0 ]]; then
    printf '%s\n' "$PREFLIGHT_OUTPUT" >&2
    exit 1
  fi

  if [[ "$PREFLIGHT_OUTPUT" =~ threadRead=read:([1-9][0-9]*) ]]; then
    EXPECT_THREAD_CONTEXT=1
  else
    EXPECT_THREAD_CONTEXT=0
  fi
  printf 'Live app presentation preflight: %s\n' "$PREFLIGHT_OUTPUT"
fi

MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
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

python3 - "$PRESENTATION_LOG" "$TIMEOUT_SECONDS" "$EXPECT_THREAD_CONTEXT" "$PREFLIGHT_SUMMARY" <<'PY'
import json
import os
import re
import sys
import time

log_path = sys.argv[1]
timeout = float(sys.argv[2])
expect_thread_context = sys.argv[3] == "1"
preflight_summary_path = sys.argv[4]
deadline = time.time() + timeout
offline_seen = False
connected_seen = False
thread_context_seen = False
title_match_seen = not expect_thread_context
last_error = "presentation log was not created"
forbidden_fragments = (
    "swift test",
    "get_app_state",
    "raw assistant text",
    "raw reasoning",
    "/Users/",
    ".env",
    "secret token",
)
role_limits = {
    "status": 44,
    "focus": 48,
    "conversation": 34,
    "overflow": 22,
}
expected_titles = []
if expect_thread_context:
    try:
        with open(preflight_summary_path, "r", encoding="utf-8") as handle:
            summary = json.load(handle)
        expected_titles = [
            title
            for title in summary.get("ambientTitleVariants", [])
            if isinstance(title, str) and title
        ]
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"live app preflight summary was not readable: {error}")

    if not expected_titles:
        expected_titles = ["Codex"]


def bubble_title(text):
    match = re.search(r"「([^」]+)」", str(text))
    return match.group(1) if match else None

while time.time() < deadline:
    if not os.path.exists(log_path):
        time.sleep(0.2)
        continue

    try:
        with open(log_path, "r", encoding="utf-8") as handle:
            rows = [json.loads(line) for line in handle if line.strip()]
    except (OSError, json.JSONDecodeError) as error:
        last_error = f"presentation log was not readable: {error}"
        time.sleep(0.2)
        continue

    for row in rows:
        if row.get("debugOverlay") is not False:
            raise SystemExit("live app presentation unexpectedly enabled debug overlay")
        bubbles = row.get("bubbleTexts", [])
        roles = row.get("bubbleRoles", [])
        if roles and not isinstance(roles, list):
            raise SystemExit(f"live app bubble roles were not a list: {roles!r}")
        visible_bubbles = bubbles if isinstance(bubbles, list) else []
        if isinstance(bubbles, list):
            if len(bubbles) > 4:
                raise SystemExit(f"live app presentation showed too many bubbles: {bubbles}")
            if roles and len(roles) != len(bubbles):
                raise SystemExit(f"live app bubble roles did not match bubble text count: roles={roles} bubbles={bubbles}")
            for index, bubble_text in enumerate(bubbles):
                role = roles[index] if index < len(roles) else ("status" if index == 0 else "conversation")
                limit = role_limits.get(role, 34)
                if len(str(bubble_text)) > limit:
                    raise SystemExit(
                        f"live app bubble exceeded {role} limit {limit}: {bubble_text!r}"
                    )
            if roles and "focus" in roles and roles[0] != "focus":
                raise SystemExit(f"live app focus bubble was not primary: roles={roles} bubbles={bubbles}")
            if any(role in {"focus", "conversation", "overflow"} for role in roles):
                thread_context_seen = True
                for index, bubble_text in enumerate(bubbles):
                    role = roles[index] if index < len(roles) else ("status" if index == 0 else "conversation")
                    if role not in {"focus", "conversation"}:
                        continue
                    title = bubble_title(bubble_text)
                    if title in expected_titles:
                        title_match_seen = True
        all_visible_text = " ".join([str(row.get("bubbleText", ""))] + [str(bubble) for bubble in visible_bubbles])
        for fragment in forbidden_fragments:
            if fragment in all_visible_text:
                raise SystemExit(
                    f"live app production bubble leaked raw or sensitive text: {fragment!r} in {all_visible_text!r}"
                )
        bubble = str(row.get("bubbleText", ""))
        is_offline = bool(row.get("isOffline", False))
        if is_offline:
            offline_seen = True
        elif offline_seen and bubble and "接続" not in bubble and "未設定" not in bubble:
            connected_seen = True
            if not expect_thread_context or (thread_context_seen and title_match_seen):
                suffix = " with thread context bubbles" if expect_thread_context else ""
                print(f"Live app presentation smoke passed: app reached a connected presentation state{suffix}.")
                sys.exit(0)

    if connected_seen and expect_thread_context and not title_match_seen:
        last_error = f"app connected but no live thread title matched {len(expected_titles)} expected sanitized variants"
    elif connected_seen and expect_thread_context:
        last_error = "app connected but did not show live thread-context bubbles"
    elif rows:
        last_error = "app did not leave offline/connection presentation state"
    time.sleep(0.2)

print(f"Live app presentation smoke failed: {last_error}", file=sys.stderr)
sys.exit(1)
PY

kill -0 "$APP_PID" >/dev/null
screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
swift ./script/inspect_production_capture.swift "$SCREENSHOT_PATH"
