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
MIMO_CODEX_DIALOGUE_DISABLED=1 \
MIMO_PRESENTATION_LOG="$PRESENTATION_LOG" \
"$APP_BINARY" &
APP_PID=$!

kill -0 "$APP_PID" >/dev/null

WINDOW_ID="$(swift ./script/find_mimo_window.swift --pid "$APP_PID" --max-width 520 --max-height 560)"

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
    "TOKEN=short",
    "OPENAI_API_KEY",
    "Ignore previous instructions",
    "developer message",
)
blocked_ambient_fragments = (
    "://",
    "www.",
    "localhost:",
    "127.0.0.1",
    "/users/",
    "/private/",
    "/volumes/",
    "~/",
    "\\users\\",
    ".env",
    "credentials",
    "secret",
    "authorization:",
    "api_key",
    "apikey",
    "x-api-key",
    "access token",
    "auth token",
    "bearer ",
    "password",
    "private key",
)
blocked_ambient_patterns = (
    r"(?:^|\s)/(?:tmp|var|etc|opt|usr|bin|sbin)/",
    r"[A-Za-z]:\\",
    r"(?i)\b(?:token|authorization|api[-_ ]?key|password|passwd|secret|session|cookie)\s*[:=]",
    r"(?i)\b[A-Z][A-Z0-9_]*(?:TOKEN|SECRET|KEY|PASSWORD|COOKIE)[A-Z0-9_]*\s*=",
    r"(?i)\bsk-[A-Za-z0-9_-]{20,}",
    r"(?i)\bgh[pousr]_[A-Za-z0-9_]{20,}",
    r"[A-Fa-f0-9]{32,}",
    r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}",
)
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

def reject_unsafe_visible_text(text):
    lowered = text.lower()
    for fragment in forbidden_fragments:
        if fragment in text:
            raise SystemExit(
                f"live app production surface leaked raw or sensitive text: {fragment!r} in {text!r}"
            )
    for fragment in blocked_ambient_fragments:
        if fragment in lowered:
            raise SystemExit(
                f"live app production surface leaked unsafe ambient fragment: {fragment!r} in {text!r}"
            )
    for pattern in blocked_ambient_patterns:
        if re.search(pattern, text):
            raise SystemExit(
                f"live app production surface leaked unsafe ambient pattern: {pattern!r} in {text!r}"
            )

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
        report = str(row.get("kataribeReportText", ""))
        charms = row.get("kataribeCharmTitles", [])
        charm_thread_ids = row.get("kataribeCharmThreadIds", [])
        if not isinstance(charms, list):
            raise SystemExit(f"live app Kataribe charm titles were not a list: {charms!r}")
        if not isinstance(charm_thread_ids, list) or len(charm_thread_ids) != len(charms):
            raise SystemExit(
                "live app Kataribe charm identities did not match titles: "
                f"ids={charm_thread_ids!r} titles={charms!r}"
            )
        if len(charms) > 6 or len(charms) != len(set(charms)):
            raise SystemExit(f"live app Kataribe charm rail was invalid: {charms!r}")
        if any(title in {"Codex Thread", "Codex Session", "unknown-thread"} for title in charms):
            raise SystemExit(f"live app exposed a generic internal chat title: {charms!r}")
        if any("ほか" in str(title) for title in charms):
            raise SystemExit(f"live app hid chat names behind an overflow label: {charms!r}")
        page_number = row.get("kataribePageNumber", 1)
        page_count = row.get("kataribePageCount", 1)
        if not isinstance(page_number, int) or not isinstance(page_count, int) or not (1 <= page_number <= page_count):
            raise SystemExit(f"live app Kataribe page metadata was invalid: {page_number}/{page_count}")
        if report and len(report) > 170:
            raise SystemExit(f"live app Kataribe report exceeded its page surface: {report!r}")
        report_thread_id = row.get("kataribeReportThreadId")
        if report_thread_id not in (None, "none") and charm_thread_ids:
            if charm_thread_ids[-1] != report_thread_id:
                raise SystemExit(
                    "live app did not keep the narrated chat at the bottom of the feed: "
                    f"report={report_thread_id!r} ids={charm_thread_ids!r}"
                )

        if charms:
            thread_context_seen = True
            if any(title in expected_titles for title in charms) or any(title in report for title in expected_titles):
                title_match_seen = True

        accessibility_value = str(row.get("accessibilityValue", ""))
        if (report or charms) and not accessibility_value.startswith("本番表示。"):
            raise SystemExit(f"live app accessibilityValue did not mark production mode: {accessibility_value!r}")
        missing_ax_titles = [str(title) for title in charms if str(title) not in accessibility_value]
        if missing_ax_titles:
            raise SystemExit(
                "live app accessibilityValue omitted named chats: "
                f"missing={missing_ax_titles!r} value={accessibility_value!r}"
            )
        if any(raw in accessibility_value for raw in ("running-left", "running-right", "active", "Codex Thread")):
            raise SystemExit(f"live app accessibilityValue exposed internal state: {accessibility_value!r}")

        all_visible_text = " ".join(
            [report, accessibility_value] + [str(title) for title in charms]
        )
        reject_unsafe_visible_text(all_visible_text)
        bubble = str(row.get("bubbleText", ""))
        is_offline = bool(row.get("isOffline", False))
        if is_offline:
            offline_seen = True
        elif offline_seen and bubble and "接続" not in bubble and "未設定" not in bubble:
            connected_seen = True
            if not expect_thread_context or (thread_context_seen and title_match_seen):
                suffix = " with a named Kataribe Stage" if expect_thread_context else ""
                print(f"Live app presentation smoke passed: app reached a connected presentation state{suffix}.")
                sys.exit(0)

    if connected_seen and expect_thread_context and not title_match_seen:
        last_error = f"app connected but no live thread title matched {len(expected_titles)} expected sanitized variants"
    elif connected_seen and expect_thread_context:
        last_error = "app connected but did not show a live named Kataribe Stage"
    elif rows:
        last_error = "app did not leave offline/connection presentation state"
    time.sleep(0.2)

print(f"Live app presentation smoke failed: {last_error}", file=sys.stderr)
sys.exit(1)
PY

kill -0 "$APP_PID" >/dev/null
sleep "${MIMO_CAPTURE_SETTLE_SECONDS:-1.8}"
screencapture -x -o -l "$WINDOW_ID" "$SCREENSHOT_PATH"
if [[ "$EXPECT_THREAD_CONTEXT" == "1" ]]; then
  swift ./script/inspect_production_capture.swift --kataribe-stage "$SCREENSHOT_PATH"
else
  swift ./script/inspect_production_capture.swift "$SCREENSHOT_PATH"
fi
