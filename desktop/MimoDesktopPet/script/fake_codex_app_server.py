#!/usr/bin/env python3
import json
import sys
import threading
import time

LOG_PATH = "/tmp/mimo-fake-codex.log"
STATE_LOCK = threading.Lock()
CURRENT_STATUS = {"type": "idle"}
CURRENT_TURNS = []


def log(message):
    with open(LOG_PATH, "a", encoding="utf-8") as handle:
        handle.write(message + "\n")


def write_message(message):
    log("out " + json.dumps(message, separators=(",", ":")))
    sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def state_sequence():
    global CURRENT_STATUS, CURRENT_TURNS
    time.sleep(2.0)
    with STATE_LOCK:
        CURRENT_STATUS = {"type": "active", "activeFlags": []}
        CURRENT_TURNS = []
    write_message(
        {
            "method": "thread/status/changed",
            "params": {
                "threadId": "fake-thread",
                "status": {"type": "active", "activeFlags": []},
            },
        }
    )
    time.sleep(3.0)
    with STATE_LOCK:
        CURRENT_STATUS = {"type": "active", "activeFlags": ["waitingOnUserInput"]}
        CURRENT_TURNS = []
    write_message(
        {
            "method": "thread/status/changed",
            "params": {
                "threadId": "fake-thread",
                "status": {"type": "active", "activeFlags": ["waitingOnUserInput"]},
            },
        }
    )
    time.sleep(3.0)
    with STATE_LOCK:
        CURRENT_STATUS = {"type": "idle"}
        CURRENT_TURNS = [{"id": "turn-review", "status": "completed"}]
    write_message(
        {
            "method": "thread/status/changed",
            "params": {
                "threadId": "fake-thread",
                "status": {"type": "idle"},
            },
        }
    )
    write_message(
        {
            "method": "turn/completed",
            "params": {
                "threadId": "fake-thread",
                "turn": {"id": "turn-review", "status": "completed"},
            },
        }
    )
    time.sleep(3.0)
    with STATE_LOCK:
        CURRENT_STATUS = {"type": "idle"}
        CURRENT_TURNS = [{"id": "turn-failed", "status": "failed"}]
    write_message(
        {
            "method": "turn/completed",
            "params": {
                "threadId": "fake-thread",
                "turn": {"id": "turn-failed", "status": "failed"},
            },
        }
    )


def run_stdio_server():
    log("stdio start")
    sequence_started = False
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
                        "userAgent": "Fake Codex App Server",
                        "codexHome": "/tmp/fake-codex-home",
                        "platformFamily": "unix",
                        "platformOs": "macos",
                    },
                }
            )
        elif method == "thread/loaded/list":
            write_message(
                {
                    "id": request_id,
                    "result": {"data": ["fake-thread"], "nextCursor": None},
                }
            )
        elif method == "thread/read":
            with STATE_LOCK:
                status = dict(CURRENT_STATUS)
                turns = [dict(turn) for turn in CURRENT_TURNS]
            write_message(
                {
                    "id": request_id,
                    "result": {
                        "thread": {
                            "id": "fake-thread",
                            "status": status,
                            "turns": turns,
                        }
                    },
                }
            )
            if not sequence_started:
                sequence_started = True
                threading.Thread(target=state_sequence, daemon=True).start()
        elif request_id is not None:
            write_message({"id": request_id, "result": {}})


def main():
    args = sys.argv[1:]
    log("argv " + json.dumps(args))
    if args == ["app-server", "daemon", "start"]:
        return 0
    if len(args) >= 2 and args[0] == "app-server" and args[1] == "--stdio":
        run_stdio_server()
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
