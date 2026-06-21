#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-full}"
APP_NAME="MimoDesktopPet"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"

usage() {
  cat >&2 <<'USAGE'
usage: ./script/qa_all.sh [full|--full|fake-only|--fake-only]

full       Run unit tests, static checks, schema/live app-server checks, and all production E2E gates.
fake-only  Run unit tests, static checks, and fake/offline production E2E gates without real app-server checks.
USAGE
}

case "$MODE" in
  full|--full)
    RUN_LIVE=1
    ;;
  fake-only|--fake-only)
    RUN_LIVE=0
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    usage
    exit 2
    ;;
esac

cleanup() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  wait_for_app_exit >/dev/null 2>&1 || true
}
trap cleanup EXIT

wait_for_app_exit() {
  for _ in {1..50}; do
    if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

terminate_existing_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  if ! wait_for_app_exit; then
    echo "$APP_NAME did not exit before the next QA app gate" >&2
    return 1
  fi
}

run_step() {
  local label="$1"
  shift
  printf '\n==> %s\n' "$label"
  "$@"
}

run_from_repo() {
  local label="$1"
  shift
  run_step "$label" "$@"
}

run_from_root() {
  local label="$1"
  shift
  (cd "$ROOT_DIR" && run_step "$label" "$@")
}

run_app_from_root() {
  local label="$1"
  shift
  terminate_existing_app
  (cd "$ROOT_DIR" && run_step "$label" "$@")
  terminate_existing_app
}

cd "$REPO_ROOT"

run_from_root "swift test" swift test
run_from_repo "shell syntax checks" bash -n \
  desktop/MimoDesktopPet/script/qa_all.sh \
  desktop/MimoDesktopPet/script/check_app_server_schema.sh \
  desktop/MimoDesktopPet/script/live_app_presentation_smoke.sh \
  desktop/MimoDesktopPet/script/test_live_app_server_smoke_retry.sh \
  desktop/MimoDesktopPet/script/test_live_app_server_smoke_transport.sh \
  desktop/MimoDesktopPet/script/e2e_fake_app_server.sh \
  desktop/MimoDesktopPet/script/e2e_content_length_app_server.sh \
  desktop/MimoDesktopPet/script/e2e_proxy_fallback_app_server.sh \
  desktop/MimoDesktopPet/script/e2e_hanging_daemon_start.sh \
  desktop/MimoDesktopPet/script/e2e_empty_thread_list.sh \
  desktop/MimoDesktopPet/script/e2e_overflow_thread_list.sh \
  desktop/MimoDesktopPet/script/e2e_thread_read_timeout.sh \
  desktop/MimoDesktopPet/script/e2e_unavailable_app_server.sh \
  desktop/MimoDesktopPet/script/e2e_disconnect_app_server.sh \
  desktop/MimoDesktopPet/script/e2e_reconnect_app_server.sh \
  desktop/MimoDesktopPet/script/e2e_single_instance.sh \
  desktop/MimoDesktopPet/script/e2e_status_menu.sh \
  desktop/MimoDesktopPet/script/e2e_state_matrix.sh
run_from_repo "python syntax checks" python3 -m py_compile \
  desktop/MimoDesktopPet/script/fake_codex_app_server.py \
  desktop/MimoDesktopPet/script/fake_disconnect_codex_app_server.py \
  desktop/MimoDesktopPet/script/fake_empty_codex_app_server.py \
  desktop/MimoDesktopPet/script/fake_flaky_live_codex_app_server.py \
  desktop/MimoDesktopPet/script/fake_hanging_read_codex_app_server.py \
  desktop/MimoDesktopPet/script/fake_overflow_codex_app_server.py \
  desktop/MimoDesktopPet/script/fake_recovering_codex_app_server.py \
  desktop/MimoDesktopPet/script/check_title_sanitizer_parity.py \
  desktop/MimoDesktopPet/script/live_app_server_smoke.py
run_from_root "title sanitizer smoke parity check" ./script/check_title_sanitizer_parity.py
run_from_root "live app-server smoke retry check" ./script/test_live_app_server_smoke_retry.sh
run_from_root "live app-server smoke transport check" ./script/test_live_app_server_smoke_transport.sh
run_from_repo "git whitespace check" git diff --check

if [[ "$RUN_LIVE" == "1" ]]; then
  run_from_root "app-server schema drift check" ./script/check_app_server_schema.sh
  run_from_root "live app-server read-only smoke" ./script/live_app_server_smoke.py
  run_app_from_root "live app presentation production smoke" ./script/live_app_presentation_smoke.sh
else
  printf '\n==> skipping live app-server checks in fake-only mode\n'
fi

run_app_from_root "fake app-server production E2E" ./script/e2e_fake_app_server.sh
run_app_from_root "content-length app-server production E2E" ./script/e2e_content_length_app_server.sh
run_app_from_root "proxy fallback production E2E" ./script/e2e_proxy_fallback_app_server.sh
run_app_from_root "hanging daemon start production E2E" ./script/e2e_hanging_daemon_start.sh
run_app_from_root "empty thread-list production E2E" ./script/e2e_empty_thread_list.sh
run_app_from_root "overflow thread-list production E2E" ./script/e2e_overflow_thread_list.sh
run_app_from_root "thread-read timeout production E2E" ./script/e2e_thread_read_timeout.sh
run_app_from_root "unavailable app-server production E2E" ./script/e2e_unavailable_app_server.sh
run_app_from_root "disconnect production E2E" ./script/e2e_disconnect_app_server.sh
run_app_from_root "reconnect production E2E" ./script/e2e_reconnect_app_server.sh
run_app_from_root "single-instance production E2E" ./script/e2e_single_instance.sh
run_app_from_root "status menu production E2E" ./script/e2e_status_menu.sh
run_app_from_root "production state matrix E2E" ./script/e2e_state_matrix.sh
run_from_root "bundle verify" ./script/build_and_run.sh --verify

printf '\nQA passed: mode=%s\n' "$MODE"
