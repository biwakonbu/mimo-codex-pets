#!/usr/bin/env python3
import json
import os
import sys
import time


COUNT_PATH = os.environ.get("MIMO_FAKE_FLAKY_LIVE_COUNT", "/tmp/mimo-flaky-live-smoke-count")


def invocation_count():
    try:
        with open(COUNT_PATH, "r", encoding="utf-8") as handle:
            count = int(handle.read().strip() or "0")
    except (OSError, ValueError):
        count = 0
    count += 1
    with open(COUNT_PATH, "w", encoding="utf-8") as handle:
        handle.write(str(count))
    return count


def write(message):
    sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def read_requests():
    for line in sys.stdin:
        line = line.strip()
        if line:
            yield json.loads(line)


def thread_snapshot():
    return {
        "id": "flaky-thread",
        "name": "Flaky live smoke",
        "preview": "Retry path",
        "status": {"type": "active", "activeFlags": []},
        "turns": [
            {
                "id": "flaky-turn",
                "status": "inProgress",
                "items": [
                    {
                        "id": "flaky-agent",
                        "type": "agentMessage",
                        "content": [{"type": "outputText", "text": "作業を進めています"}],
                    }
                ],
            }
        ],
    }


def run_stdio():
    count = invocation_count()
    for request in read_requests():
        method = request.get("method")
        request_id = request.get("id")
        if request_id is None:
            continue

        if method == "initialize":
            write(
                {
                    "id": request_id,
                    "result": {
                        "userAgent": "Fake Flaky Codex App Server",
                        "codexHome": "/tmp/fake-codex-home",
                        "platformFamily": "unix",
                        "platformOs": "macos",
                    },
                }
            )
        elif method == "thread/loaded/list":
            if count == 1:
                time.sleep(5)
                return
            write({"id": request_id, "result": {"data": [], "nextCursor": None}})
        elif method == "thread/list":
            write({"id": request_id, "result": {"data": [thread_snapshot()], "nextCursor": None}})
        elif method == "thread/read":
            write({"id": request_id, "result": {"thread": thread_snapshot()}})
        else:
            write({"id": request_id, "result": {}})


def main():
    args = sys.argv[1:]
    if args == ["app-server", "--stdio"]:
        run_stdio()
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
