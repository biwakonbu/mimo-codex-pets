#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAKE_CODEX="$ROOT_DIR/script/fake_codex_app_server.py"
FAKE_LOG="/tmp/mimo-fake-codex.log"
PROXY_SUMMARY="/tmp/mimo-live-smoke-proxy-summary-$$.json"
FALLBACK_SUMMARY="/tmp/mimo-live-smoke-fallback-summary-$$.json"

cleanup() {
  rm -f "$FAKE_LOG" "$PROXY_SUMMARY" "$FALLBACK_SUMMARY"
}
trap cleanup EXIT

cd "$ROOT_DIR"

rm -f "$FAKE_LOG" "$PROXY_SUMMARY"
PROXY_OUTPUT="$(
  MIMO_CODEX_EXECUTABLE="$FAKE_CODEX" \
  MIMO_LIVE_SMOKE_TIMEOUT=0.4 \
  MIMO_LIVE_SMOKE_DAEMON_START_TIMEOUT=0.4 \
  ./script/live_app_server_smoke.py --transport auto --attempts 1 --summary-json "$PROXY_SUMMARY" 2>&1
)"

grep -Fq "transport='proxy'" <<<"$PROXY_OUTPUT"
grep -Fq 'argv ["app-server", "daemon", "start"]' "$FAKE_LOG"
grep -Fq 'argv ["app-server", "proxy"]' "$FAKE_LOG"
if grep -Fq 'argv ["app-server", "--stdio"]' "$FAKE_LOG"; then
  echo "proxy transport smoke unexpectedly used direct stdio" >&2
  exit 1
fi

rm -f "$FAKE_LOG" "$FALLBACK_SUMMARY"
FALLBACK_OUTPUT="$(
  CODEX_BIN="$FAKE_CODEX" \
  MIMO_FAKE_CODEX_FAIL_PROXY=1 \
  MIMO_LIVE_SMOKE_TIMEOUT=0.4 \
  MIMO_LIVE_SMOKE_DAEMON_START_TIMEOUT=0.4 \
  ./script/live_app_server_smoke.py --transport auto --attempts 1 --summary-json "$FALLBACK_SUMMARY" 2>&1
)"

grep -Fq "proxy unavailable before initialize" <<<"$FALLBACK_OUTPUT"
grep -Fq "transport='stdio-fallback'" <<<"$FALLBACK_OUTPUT"
grep -Fq 'argv ["app-server", "daemon", "start"]' "$FAKE_LOG"
grep -Fq 'argv ["app-server", "proxy"]' "$FAKE_LOG"
grep -Fq 'proxy failing' "$FAKE_LOG"
grep -Fq 'argv ["app-server", "--stdio"]' "$FAKE_LOG"

python3 - "$PROXY_SUMMARY" "$FALLBACK_SUMMARY" <<'PY'
import json
import sys

proxy_summary_path, fallback_summary_path = sys.argv[1:]
with open(proxy_summary_path, "r", encoding="utf-8") as handle:
    proxy_summary = json.load(handle)
with open(fallback_summary_path, "r", encoding="utf-8") as handle:
    fallback_summary = json.load(handle)

if proxy_summary.get("transport") != "proxy":
    raise SystemExit(f"unexpected proxy summary: {proxy_summary}")
if fallback_summary.get("transport") != "stdio-fallback":
    raise SystemExit(f"unexpected fallback summary: {fallback_summary}")
if proxy_summary.get("threadReadCount", 0) < 1 or fallback_summary.get("threadReadCount", 0) < 1:
    raise SystemExit(f"expected thread reads in both summaries: {proxy_summary} / {fallback_summary}")
PY

echo "Transport smoke passed: live_app_server_smoke.py uses proxy first and falls back to direct stdio before initialize."
