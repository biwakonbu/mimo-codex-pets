#!/usr/bin/env python3
import json
import os
import sys
import threading
import time


LOG_PATH = "/tmp/mimo-disconnect-fake-codex.log"


def log(message):
    with open(LOG_PATH, "a", encoding="utf-8") as handle:
        handle.write(message + "\n")


def write_message(message):
    log("out " + json.dumps(message, separators=(",", ":")))
    sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def thread_snapshot():
    return {
        "id": "disconnect-thread",
        "name": "切断耐性の確認",
        "preview": "接続後に app-server が落ちる検証",
        "status": {"type": "active", "activeFlags": []},
        "turns": [
            {
                "id": "turn-disconnect",
                "status": "inProgress",
                "items": [
                    {
                        "id": "u-disconnect",
                        "type": "userMessage",
                        "content": [{"type": "inputText", "text": "接続が切れても落ちないで"}],
                    },
                    {
                        "id": "a-disconnect",
                        "type": "agentMessage",
                        "content": [{"type": "outputText", "text": "切断時の表示を確認しています"}],
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
        time.sleep(0.4)
        log("disconnecting stdio")
        os._exit(0)

    threading.Thread(target=exit_later, daemon=True).start()


def run_stdio_server():
    log("stdio start")
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
                        "userAgent": "Fake Disconnect Codex App Server",
                        "codexHome": "/tmp/fake-disconnect-codex-home",
                        "platformFamily": "unix",
                        "platformOs": "macos",
                    },
                }
            )
        elif method == "thread/loaded/list":
            write_message(
                {
                    "id": request_id,
                    "result": {"data": ["disconnect-thread"], "nextCursor": None},
                }
            )
        elif method == "thread/list":
            write_message(
                {
                    "id": request_id,
                    "result": {"data": [thread_snapshot()], "nextCursor": None},
                }
            )
        elif method == "thread/read":
            write_message(
                {
                    "id": request_id,
                    "result": {"thread": thread_snapshot()},
                }
            )
            schedule_exit_once(state)
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
