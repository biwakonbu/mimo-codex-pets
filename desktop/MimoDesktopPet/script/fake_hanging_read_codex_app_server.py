#!/usr/bin/env python3
import json
import sys


LOG_PATH = "/tmp/mimo-hanging-read-fake-codex.log"


def log(message):
    with open(LOG_PATH, "a", encoding="utf-8") as handle:
        handle.write(message + "\n")


def write_message(message):
    log("out " + json.dumps(message, separators=(",", ":")))
    sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def thread_snapshot():
    return {
        "id": "timeout-thread",
        "name": "Timeout QA",
        "preview": "thread/read が返らない時の表示確認",
        "status": {"type": "active", "activeFlags": []},
        "turns": [
            {
                "id": "turn-timeout",
                "status": "inProgress",
                "items": [
                    {
                        "id": "user-timeout",
                        "type": "userMessage",
                        "content": [{"type": "inputText", "text": "応答待ちで固まらないで"}],
                    }
                ],
            }
        ],
    }


def run_stdio_server():
    log("stdio start")
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
                        "userAgent": "Fake Hanging Read Codex App Server",
                        "codexHome": "/tmp/fake-hanging-read-codex-home",
                        "platformFamily": "unix",
                        "platformOs": "macos",
                    },
                }
            )
        elif method == "thread/loaded/list":
            write_message(
                {
                    "id": request_id,
                    "result": {"data": ["timeout-thread"], "nextCursor": None},
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
            log("holding thread/read response")
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
