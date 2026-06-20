#!/usr/bin/env python3
import argparse
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


def parse_args():
    parser = argparse.ArgumentParser(description="Read-only smoke test for Codex app-server.")
    parser.add_argument(
        "--summary-json",
        help="Write a machine-readable summary for follow-up presentation checks.",
    )
    return parser.parse_args()


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


def ambient_titles(thread_objects):
    variants = []
    for thread in thread_objects:
        title_16 = compact_title(
            [thread.get("name"), thread.get("preview"), "Codex Thread"],
            limit=16,
        )
        title_12 = compact_title(
            [thread.get("name"), thread.get("preview"), "Codex Thread"],
            limit=12,
        )
        for title in [title_16, title_12]:
            if title not in variants:
                variants.append(title)
    return variants


def compact_title(candidates, limit):
    title = safe_title(candidates, fallback="Codex Thread", limit=limit)
    if title in {"Codex Thread", "unknown-thread"}:
        return "Codex"
    return title or "Codex"


def safe_title(candidates, fallback, limit):
    for candidate in candidates:
        text = raw_text(candidate)
        if text is None:
            continue
        collapsed = " ".join(text.split()).strip()
        if not collapsed:
            continue
        if looks_like_instruction_title(collapsed) or looks_unsafe_for_ambient_display(collapsed):
            continue
        if len(collapsed) <= limit:
            return collapsed
        return collapsed[:limit].strip() + "..."
    return fallback


def raw_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return " ".join(part for part in (raw_text(item) for item in value) if part)
    if isinstance(value, dict):
        for key in ["name", "title", "preview", "text", "content", "message"]:
            text = raw_text(value.get(key))
            if text:
                return text
    return None


def looks_like_instruction_title(title):
    lowercased = title.lower()
    blocked_prefixes = (
        "you are ",
        "knowledge cutoff",
        "current date",
        "<codex_internal_context",
        "# instructions",
        "system:",
    )
    if any(lowercased.startswith(prefix) for prefix in blocked_prefixes):
        return True

    blocked_fragments = (
        "treat it as the task",
        "higher-priority instructions",
        "do not reveal",
        "you are selected",
    )
    return any(fragment in lowercased for fragment in blocked_fragments)


def looks_unsafe_for_ambient_display(title):
    import re

    lowercased = title.lower()
    blocked_fragments = (
        "://",
        "www.",
        "localhost:",
        "127.0.0.1",
        "/users/",
        "/private/",
        "/volumes/",
        "~/",
        "\\users\\",
        ".env",
        "credentials",
        "secret",
        "api_key",
        "apikey",
        "access token",
        "bearer ",
        "password",
    )
    if any(fragment in lowercased for fragment in blocked_fragments):
        return True

    blocked_patterns = (
        r"(?:^|\s)/(?:tmp|var|etc|opt|usr|bin|sbin)/",
        r"[A-Za-z]:\\",
        r"[A-Fa-f0-9]{32,}",
        r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}",
    )
    return any(re.search(pattern, title) for pattern in blocked_patterns)


def write_summary(path, initialize, loaded, listed, thread_objects, read_count):
    summary = {
        "userAgent": initialize.get("userAgent") if isinstance(initialize, dict) else None,
        "loadedLimit": LOADED_THREAD_LIMIT,
        "listedLimit": LISTED_THREAD_LIMIT,
        "loadedCount": len(loaded.get("data", [])) if isinstance(loaded, dict) else None,
        "listedCount": len(listed.get("data", [])) if isinstance(listed, dict) else None,
        "threadReadCount": read_count,
        "ambientTitleVariants": ambient_titles(thread_objects),
    }
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(summary, handle, ensure_ascii=False, separators=(",", ":"))
        handle.write("\n")


def main():
    args = parse_args()
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
        thread_objects = []
        for offset, thread_id in enumerate(candidate_thread_ids):
            read = request(
                process,
                4 + offset,
                "thread/read",
                {"threadId": thread_id, "includeTurns": True},
            )
            if not isinstance(read, dict) or not isinstance(read.get("thread"), dict):
                raise SmokeFailure(f"thread/read response did not include thread for {thread_id!r}")
            thread_objects.append(read["thread"])
            read_count += 1

        read_status = f"read:{read_count}" if read_count else "skipped-no-thread"
        if args.summary_json:
            write_summary(args.summary_json, initialize, loaded, listed, thread_objects, read_count)

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
