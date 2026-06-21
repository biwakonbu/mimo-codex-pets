#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME"
FAKE_CODEX="$ROOT_DIR/script/fake_empty_codex_app_server.py"
LOCK_PATH="/tmp/mimo-status-menu-e2e.lock"
MENU_LOG="/tmp/mimo-status-menu-e2e.jsonl"

cleanup() {
  if [[ -n "${APP_PID:-}" ]] && kill -0 "$APP_PID" >/dev/null 2>&1; then
    kill "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  rm -f "$LOCK_PATH"
}
trap cleanup EXIT

launch_and_assert_menu() {
  local label="$1"
  local expected_debug_visible="$2"
  local debug_menu_env="$3"
  local debug_overlay_env="$4"

  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  rm -f "$LOCK_PATH" "$MENU_LOG"
  unset APP_PID

  CODEX_BIN="$FAKE_CODEX" \
  MIMO_PET_PACKAGE_DIR="$REPO_ROOT/pets/mimo" \
  MIMO_AUTONOMOUS_DISABLED=1 \
  MIMO_BUBBLE_TEST_MODE=1 \
  MIMO_SINGLE_INSTANCE_LOCK_PATH="$LOCK_PATH" \
  MIMO_STATUS_MENU_LOG="$MENU_LOG" \
  MIMO_DEBUG_MENU="$debug_menu_env" \
  MIMO_DEBUG_OVERLAY="$debug_overlay_env" \
  "$APP_BINARY" &
  APP_PID=$!

  python3 - "$MENU_LOG" "$expected_debug_visible" "$label" <<'PY'
import json
import os
import sys
import time

log_path, expected_raw, label = sys.argv[1:]
expected = expected_raw == "1"
deadline = time.time() + 8
last_error = "menu log did not appear"

while time.time() < deadline:
    if not os.path.exists(log_path):
        time.sleep(0.15)
        continue
    try:
        with open(log_path, "r", encoding="utf-8") as handle:
            rows = [json.loads(line) for line in handle if line.strip()]
    except (OSError, json.JSONDecodeError) as error:
        last_error = f"menu log was not readable: {error}"
        time.sleep(0.15)
        continue

    for row in rows:
        titles = row.get("menuTitles", [])
        debug_visible = bool(row.get("debugMenuVisible", False))
        required = ["Show Mimo", "Hide Mimo", "Click Through", "Reconnect Codex", "Quit"]
        missing = [title for title in required if title not in titles]
        if missing:
            raise SystemExit(f"{label}: required menu items missing: {missing}; titles={titles}")
        if debug_visible != expected:
            raise SystemExit(
                f"{label}: debug menu visibility was {debug_visible}, expected {expected}; titles={titles}"
            )
        if ("Debug Overlay" in titles) != expected:
            raise SystemExit(f"{label}: Debug Overlay title mismatch; titles={titles}")
        states = row.get("itemStates", {})
        if bool(row.get("clickThroughEnabled", True)):
            raise SystemExit(f"{label}: Click Through should start disabled; row={row}")
        if bool(states.get("Click Through", True)):
            raise SystemExit(f"{label}: Click Through menu state should start off; states={states}")
        debug_enabled = bool(row.get("debugOverlayEnabled", False))
        debug_state = bool(states.get("Debug Overlay", False))
        if label == "debug-overlay-opt-in":
            if not debug_enabled or not debug_state:
                raise SystemExit(f"{label}: Debug Overlay should start enabled; row={row}")
        elif debug_enabled or debug_state:
            raise SystemExit(f"{label}: Debug Overlay should start disabled; row={row}")
        print(f"{label} status menu observed.")
        raise SystemExit(0)

    last_error = "menu log contained no rows"
    time.sleep(0.15)

raise SystemExit(f"{label}: {last_error}")
PY

  kill "$APP_PID" >/dev/null 2>&1 || true
  wait "$APP_PID" >/dev/null 2>&1 || true
  unset APP_PID
}

cd "$ROOT_DIR"
./script/build_and_run.sh --verify

launch_and_assert_menu "production" "0" "" ""
launch_and_assert_menu "debug-menu-opt-in" "1" "1" ""
launch_and_assert_menu "debug-overlay-opt-in" "1" "" "1"

echo "E2E passed: production status menu hides Debug Overlay unless debug mode is explicitly enabled."
