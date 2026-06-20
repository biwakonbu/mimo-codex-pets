#!/usr/bin/env python3
import json
import sys
import threading
import time

LOG_PATH = "/tmp/mimo-fake-codex.log"
STATE_LOCK = threading.Lock()
CURRENT_STATUS = {"type": "idle"}
CURRENT_TURNS = [
    {
        "id": "turn-idle",
        "status": "completed",
        "items": [
            {"id": "u1", "type": "userMessage", "content": [{"type": "inputText", "text": "Mimo の動きを確認して"}]},
            {"id": "a1", "type": "agentMessage", "content": [{"type": "outputText", "text": "待機中です。会話を監視しています"}]},
        ],
    }
]
SECOND_THREAD = {
    "id": "fake-review",
    "name": "別スレッドの確認",
    "preview": "レビュー可能な結果があります",
    "status": {"type": "idle"},
    "turns": [
        {
            "id": "turn-other",
            "status": "completed",
            "items": [
                {"id": "u2", "type": "userMessage", "content": [{"type": "inputText", "text": "QA 結果を見せて"}]},
                {"id": "a2", "type": "agentMessage", "content": [{"type": "outputText", "text": "検証はすべて通っています"}]},
            ],
        }
    ],
}


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
        CURRENT_TURNS = [
            {
                "id": "turn-active",
                "status": "inProgress",
                "items": [
                    {"id": "u3", "type": "userMessage", "content": [{"type": "inputText", "text": "デスクトップ上を歩いて"}]},
                    {"id": "c1", "type": "commandExecution", "command": ["swift", "test"]},
                    {"id": "a3", "type": "agentMessage", "content": [{"type": "outputText", "text": "移動先を決めながら作業しています"}]},
                ],
            }
        ]
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
        CURRENT_TURNS = [
            {
                "id": "turn-waiting",
                "status": "inProgress",
                "items": [
                    {"id": "u4", "type": "userMessage", "content": [{"type": "inputText", "text": "確認待ちの時は止まって"}]},
                    {"id": "a4", "type": "agentMessage", "content": [{"type": "outputText", "text": "入力を待ちながらメモを取っています"}]},
                ],
            }
        ]
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
        CURRENT_TURNS = [
            {
                "id": "turn-review",
                "status": "completed",
                "items": [
                    {"id": "u5", "type": "userMessage", "content": [{"type": "inputText", "text": "結果をレビューして"}]},
                    {"id": "a5", "type": "agentMessage", "content": [{"type": "outputText", "text": "レビューできる状態になりました"}]},
                ],
            }
        ]
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
        CURRENT_TURNS = [
            {
                "id": "turn-failed",
                "status": "failed",
                "items": [
                    {"id": "u6", "type": "userMessage", "content": [{"type": "inputText", "text": "失敗も表示して"}]},
                    {"id": "a6", "type": "agentMessage", "content": [{"type": "outputText", "text": "実行に失敗しました。確認が必要です"}]},
                ],
            }
        ]
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
                    "result": {"data": ["fake-thread", "fake-review"], "nextCursor": None},
                }
            )
        elif method == "thread/list":
            with STATE_LOCK:
                status = dict(CURRENT_STATUS)
                turns = [dict(turn) for turn in CURRENT_TURNS]
            write_message(
                {
                    "id": request_id,
                    "result": {
                        "data": [
                            {
                                "id": "fake-thread",
                                "name": "Mimo runtime QA",
                                "preview": "自律移動と会話表示を検証中",
                                "status": status,
                                "turns": turns,
                            },
                            SECOND_THREAD,
                        ],
                        "nextCursor": None,
                    },
                }
            )
        elif method == "thread/read":
            thread_id = request.get("params", {}).get("threadId", "fake-thread")
            if thread_id == "fake-review":
                thread = SECOND_THREAD
            else:
                with STATE_LOCK:
                    status = dict(CURRENT_STATUS)
                    turns = [dict(turn) for turn in CURRENT_TURNS]
                thread = {
                    "id": "fake-thread",
                    "name": "Mimo runtime QA",
                    "preview": "自律移動と会話表示を検証中",
                    "status": status,
                    "turns": turns,
                }
            write_message(
                {
                    "id": request_id,
                    "result": {"thread": thread},
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
    if len(args) >= 2 and args[0] == "app-server" and args[1] in ("--stdio", "proxy"):
        run_stdio_server()
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
