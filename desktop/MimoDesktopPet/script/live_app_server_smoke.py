#!/usr/bin/env python3
import json
import os
import select
import subprocess
import sys
import time


CODEX_BIN = os.environ.get("CODEX_BIN", "codex")
TIMEOUT_SECONDS = float(os.environ.get("MIMO_LIVE_SMOKE_TIMEOUT", "8"))
LOADED_THREAD_LIMIT = 10
LISTED_THREAD_LIMIT = 6


class SmokeFailure(Exception):
    pass


def write_request(process, request_id, method, params):
    payload = {
        "id": request_id,
        "method": method,
        "params": params,
    }
    process.stdin.write(json.dumps(payload, separators=(",", ":")) + "\n")
    process.stdin.flush()


def write_notification(process, method, params=None):
    payload = {
        "method": method,
    }
    if params is not None:
        payload["params"] = params
    process.stdin.write(json.dumps(payload, separators=(",", ":")) + "\n")
    process.stdin.flush()


def read_response(process, request_id, timeout=TIMEOUT_SECONDS):
    deadline = time.time() + timeout
    while time.time() < deadline:
        readable, _, _ = select.select([process.stdout, process.stderr], [], [], 0.25)
        for handle in readable:
            line = handle.readline()
            if not line:
                continue
            if handle is process.stderr:
                continue
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                continue
            if message.get("method"):
                continue
            if message.get("id") != request_id:
                continue
            if "error" in message:
                raise SmokeFailure(f"{request_id} returned error: {message['error']}")
            return message.get("result")
    raise SmokeFailure(f"timed out waiting for response id {request_id}")


def request(process, request_id, method, params):
    write_request(process, request_id, method, params)
    return read_response(process, request_id)


def thread_ids(loaded_result, list_result):
    ids = []
    if isinstance(loaded_result, dict):
        data = loaded_result.get("data")
        if isinstance(data, list):
            ids.extend(item for item in data if isinstance(item, str))
    if isinstance(list_result, dict):
        data = list_result.get("data")
        if isinstance(data, list):
            for thread in data:
                if isinstance(thread, dict) and isinstance(thread.get("id"), str):
                    ids.append(thread["id"])

    unique_ids = []
    for thread_id in ids:
        if thread_id not in unique_ids:
            unique_ids.append(thread_id)
    return unique_ids[:LISTED_THREAD_LIMIT]


def main():
    process = None
    try:
        process = subprocess.Popen(
            [CODEX_BIN, "app-server", "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=0,
        )
        initialize = request(
            process,
            1,
            "initialize",
            {
                "clientInfo": {
                    "name": "mimo_desktop_pet_smoke",
                    "title": "Mimo Desktop Pet Smoke",
                    "version": "0.1.0",
                },
                "capabilities": {"experimentalApi": True},
            },
        )
        if not isinstance(initialize, dict) or "userAgent" not in initialize:
            raise SmokeFailure("initialize response did not include userAgent")

        write_notification(process, "initialized")
        loaded = request(process, 2, "thread/loaded/list", {"limit": LOADED_THREAD_LIMIT})
        listed = request(process, 3, "thread/list", {"limit": LISTED_THREAD_LIMIT, "archived": False})
        candidate_thread_ids = thread_ids(loaded, listed)
        read_count = 0
        for offset, thread_id in enumerate(candidate_thread_ids):
            read = request(
                process,
                4 + offset,
                "thread/read",
                {"threadId": thread_id, "includeTurns": True},
            )
            if not isinstance(read, dict) or not isinstance(read.get("thread"), dict):
                raise SmokeFailure(f"thread/read response did not include thread for {thread_id!r}")
            read_count += 1

        read_status = f"read:{read_count}" if read_count else "skipped-no-thread"

        print(
            "Live app-server smoke passed: "
            f"userAgent={initialize['userAgent']!r}, "
            f"loadedLimit={LOADED_THREAD_LIMIT}, "
            f"listedLimit={LISTED_THREAD_LIMIT}, "
            f"loaded={len(loaded.get('data', [])) if isinstance(loaded, dict) else 'unknown'}, "
            f"listed={len(listed.get('data', [])) if isinstance(listed, dict) else 'unknown'}, "
            f"threadRead={read_status}."
        )
        return 0
    except FileNotFoundError:
        print(f"Codex binary not found: {CODEX_BIN}", file=sys.stderr)
        return 1
    except SmokeFailure as error:
        print(f"Live app-server smoke failed: {error}", file=sys.stderr)
        return 1
    finally:
        if process is not None:
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


if __name__ == "__main__":
    raise SystemExit(main())
