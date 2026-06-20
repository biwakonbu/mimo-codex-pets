#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAKE_CODEX="$ROOT_DIR/script/fake_flaky_live_codex_app_server.py"
COUNT_PATH="/tmp/mimo-flaky-live-smoke-count-$$"
SUMMARY_PATH="/tmp/mimo-flaky-live-smoke-summary-$$.json"

cleanup() {
  rm -f "$COUNT_PATH" "$SUMMARY_PATH"
}
trap cleanup EXIT

cd "$ROOT_DIR"

OUTPUT="$(
  CODEX_BIN="$FAKE_CODEX" \
  MIMO_FAKE_FLAKY_LIVE_COUNT="$COUNT_PATH" \
  MIMO_LIVE_SMOKE_TIMEOUT=0.2 \
  ./script/live_app_server_smoke.py --attempts 2 --summary-json "$SUMMARY_PATH" 2>&1
)"

grep -Fq "transient failure on attempt 1/2" <<<"$OUTPUT"
grep -Fq "Live app-server smoke passed:" <<<"$OUTPUT"
grep -Fq "threadRead=read:1" <<<"$OUTPUT"

python3 - "$COUNT_PATH" "$SUMMARY_PATH" <<'PY'
import json
import sys

count_path, summary_path = sys.argv[1:]
with open(count_path, "r", encoding="utf-8") as handle:
    count = int(handle.read().strip())
if count != 2:
    raise SystemExit(f"expected two fake app-server invocations, got {count}")

with open(summary_path, "r", encoding="utf-8") as handle:
    summary = json.load(handle)
if summary.get("threadReadCount") != 1:
    raise SystemExit(f"unexpected summary: {summary}")
PY

echo "Retry smoke passed: live_app_server_smoke.py retries transient timeouts with a fresh app-server process."
