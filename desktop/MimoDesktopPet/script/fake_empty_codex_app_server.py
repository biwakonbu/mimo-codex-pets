#!/usr/bin/env python3
import json
import sys

LOG_PATH = "/tmp/mimo-empty-fake-codex.log"


def log(message):
    with open(LOG_PATH, "a", encoding="utf-8") as handle:
        handle.write(message + "\n")


def write_message(message):
    log("out " + json.dumps(message, separators=(",", ":")))
    sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
    sys.stdout.flush()


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
                        "userAgent": "Empty Fake Codex App Server",
                        "codexHome": "/tmp/empty-fake-codex-home",
                        "platformFamily": "unix",
                        "platformOs": "macos",
                    },
                }
            )
        elif method == "thread/loaded/list":
            write_message({"id": request_id, "result": {"data": [], "nextCursor": None}})
        elif method == "thread/list":
            write_message({"id": request_id, "result": {"data": [], "nextCursor": None}})
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
