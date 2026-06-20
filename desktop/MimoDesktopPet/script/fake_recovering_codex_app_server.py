#!/usr/bin/env python3
import json
import os
import sys
import threading
import time


LOG_PATH = "/tmp/mimo-recovering-fake-codex.log"
STATE_PATH = "/tmp/mimo-recovering-fake-codex-state.txt"


def log(message):
    with open(LOG_PATH, "a", encoding="utf-8") as handle:
        handle.write(message + "\n")


def write_message(message):
    log("out " + json.dumps(message, separators=(",", ":")))
    sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def next_stdio_count():
    try:
        with open(STATE_PATH, "r", encoding="utf-8") as handle:
            count = int(handle.read().strip() or "0")
    except (FileNotFoundError, ValueError):
        count = 0

    count += 1
    with open(STATE_PATH, "w", encoding="utf-8") as handle:
        handle.write(str(count))
    return count


def thread_snapshot(recovered):
    if recovered:
        name = "再接続後の確認"
        preview = "Codex app-server 復帰を確認しています"
        output = "復帰後のセッションを読み直しています"
    else:
        name = "再接続前の確認"
        preview = "接続後に一度 app-server が落ちる検証"
        output = "切断前の表示を確認しています"

    return {
        "id": "recover-thread",
        "name": name,
        "preview": preview,
        "status": {"type": "active", "activeFlags": []},
        "turns": [
            {
                "id": "turn-recover",
                "status": "inProgress",
                "items": [
                    {
                        "id": "u-recover",
                        "type": "userMessage",
                        "content": [{"type": "inputText", "text": "切れても戻ってきて"}],
                    },
                    {
                        "id": "a-recover",
                        "type": "agentMessage",
                        "content": [{"type": "outputText", "text": output}],
                    },
                ],
            }
        ],
    }


def schedule_exit_once(state):
    if state["exit_scheduled"]:
        return
    state["exit_scheduled"] = True

    def exit_later():
        time.sleep(0.35)
        log("disconnecting first stdio")
        os._exit(0)

    threading.Thread(target=exit_later, daemon=True).start()


def run_stdio_server():
    count = next_stdio_count()
    recovered = count >= 2
    log(f"stdio start count={count}")
    state = {"exit_scheduled": False}

    for line in sys.stdin:
        if not line.strip():
            continue
        log("in " + line.strip())
        request = json.loads(line)
        method = request.get("method")
        request_id = request.get("id")

        if method == "initialize":
            write_message(
                {
                    "id": request_id,
                    "result": {
                        "userAgent": "Fake Recovering Codex App Server",
                        "codexHome": "/tmp/fake-recovering-codex-home",
                        "platformFamily": "unix",
                        "platformOs": "macos",
                    },
                }
            )
        elif method == "thread/loaded/list":
            write_message(
                {
                    "id": request_id,
                    "result": {"data": ["recover-thread"], "nextCursor": None},
                }
            )
        elif method == "thread/list":
            write_message(
                {
                    "id": request_id,
                    "result": {"data": [thread_snapshot(recovered)], "nextCursor": None},
                }
            )
        elif method == "thread/read":
            write_message(
                {
                    "id": request_id,
                    "result": {"thread": thread_snapshot(recovered)},
                }
            )
            if not recovered:
                schedule_exit_once(state)
            else:
                log("recovered stdio stayed available")
        elif request_id is not None:
            write_message({"id": request_id, "result": {}})


def main():
    args = sys.argv[1:]
    log("argv " + json.dumps(args))
    if args == ["app-server", "daemon", "start"]:
        return 0
    if len(args) >= 2 and args[0] == "app-server" and args[1] in ("--stdio", "proxy"):
        run_stdio_server()
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
