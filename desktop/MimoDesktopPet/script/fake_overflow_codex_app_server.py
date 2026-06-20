#!/usr/bin/env python3
import json
import sys

LOG_PATH = "/tmp/mimo-overflow-fake-codex.log"
THREADS = [
    ("overflow-1", "主作業", "Mimo の主作業を進めています"),
    ("overflow-2", "実装確認", "実装確認を進めています"),
    ("overflow-3", "UI 調整", "UI 調整を進めています"),
    ("overflow-4", "テスト追加", "テスト追加を進めています"),
    ("overflow-5", "資料整理", "資料整理を進めています"),
    ("overflow-6", "リリース準備", "リリース準備を進めています"),
]


def log(message):
    with open(LOG_PATH, "a", encoding="utf-8") as handle:
        handle.write(message + "\n")


def thread_snapshot(thread_id, name, preview):
    return {
        "id": thread_id,
        "name": name,
        "preview": preview,
        "status": {"type": "active", "activeFlags": []},
        "turns": [],
    }


def all_thread_snapshots():
    return [thread_snapshot(*thread) for thread in THREADS]


def write_message(message):
    log("out " + json.dumps(message, separators=(",", ":")))
    sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def run_stdio_server():
    log("stdio start")
    snapshots_by_id = {thread["id"]: thread for thread in all_thread_snapshots()}
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
                        "userAgent": "Overflow Fake Codex App Server",
                        "codexHome": "/tmp/overflow-fake-codex-home",
                        "platformFamily": "unix",
                        "platformOs": "macos",
                    },
                }
            )
        elif method == "thread/loaded/list":
            write_message(
                {
                    "id": request_id,
                    "result": {
                        "data": [thread_id for thread_id, _, _ in THREADS],
                        "nextCursor": None,
                    },
                }
            )
        elif method == "thread/list":
            write_message(
                {
                    "id": request_id,
                    "result": {"data": all_thread_snapshots(), "nextCursor": None},
                }
            )
        elif method == "thread/read":
            thread_id = request.get("params", {}).get("threadId")
            write_message({"id": request_id, "result": {"thread": snapshots_by_id.get(thread_id)}})
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
