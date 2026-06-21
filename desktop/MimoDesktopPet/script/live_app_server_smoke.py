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
ATTEMPTS = int(os.environ.get("MIMO_LIVE_SMOKE_ATTEMPTS", "2"))
DAEMON_START_TIMEOUT_SECONDS = float(os.environ.get("MIMO_LIVE_SMOKE_DAEMON_START_TIMEOUT", "2"))
PROXY_INITIALIZE_TIMEOUT_SECONDS = float(
    os.environ.get("MIMO_LIVE_SMOKE_PROXY_INITIALIZE_TIMEOUT", str(min(3.0, TIMEOUT_SECONDS)))
)
LOADED_THREAD_LIMIT = 10
LISTED_THREAD_LIMIT = 6


class SmokeFailure(Exception):
    pass


class TransientSmokeFailure(SmokeFailure):
    def __init__(self, request_id, message=None):
        self.request_id = request_id
        super().__init__(message or f"timed out waiting for response id {request_id}")


def parse_args():
    parser = argparse.ArgumentParser(description="Read-only smoke test for Codex app-server.")
    parser.add_argument(
        "--summary-json",
        help="Write a machine-readable summary for follow-up presentation checks.",
    )
    parser.add_argument(
        "--attempts",
        type=int,
        default=ATTEMPTS,
        help="Retry transient app-server response timeouts this many times. Defaults to MIMO_LIVE_SMOKE_ATTEMPTS or 2.",
    )
    parser.add_argument(
        "--transport",
        choices=("auto", "stdio", "proxy"),
        default=os.environ.get("MIMO_LIVE_SMOKE_TRANSPORT", "auto"),
        help="Transport to smoke. auto mirrors production: daemon start, proxy, then direct stdio fallback before initialize.",
    )
    return parser.parse_args()


def write_request(process, request_id, method, params):
    payload = {
        "id": request_id,
        "method": method,
        "params": params,
    }
    try:
        process.stdin.write(json.dumps(payload, separators=(",", ":")) + "\n")
        process.stdin.flush()
    except (BrokenPipeError, OSError) as error:
        raise TransientSmokeFailure(request_id, f"failed writing request id {request_id}: {error}") from error


def write_notification(process, method, params=None):
    payload = {
        "method": method,
    }
    if params is not None:
        payload["params"] = params
    try:
        process.stdin.write(json.dumps(payload, separators=(",", ":")) + "\n")
        process.stdin.flush()
    except (BrokenPipeError, OSError) as error:
        raise SmokeFailure(f"failed writing notification {method!r}: {error}") from error


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
    raise TransientSmokeFailure(request_id)


def request(process, request_id, method, params, timeout=TIMEOUT_SECONDS):
    write_request(process, request_id, method, params)
    return read_response(process, request_id, timeout=timeout)


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
        if is_unsafe_for_ambient_display(collapsed):
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


def is_unsafe_for_ambient_display(title):
    return (
        looks_like_instruction_title(title)
        or looks_like_machine_payload(title)
        or looks_unsafe_for_ambient_display(title)
    )


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
        "ignore previous instructions",
        "disregard previous instructions",
        "system prompt",
        "developer message",
        "do not reveal",
        "you are selected",
    )
    return any(fragment in lowercased for fragment in blocked_fragments)


def looks_like_machine_payload(title):
    trimmed = title.strip()
    lowercased = trimmed.lower()
    if (trimmed.startswith("{") or trimmed.startswith("[")) and ":" in trimmed:
        return True
    if trimmed.startswith("<") and trimmed.endswith(">"):
        return True

    payload_markers = (
        '"bundle_id"',
        '"element_id"',
        '"window_id"',
        '"question"',
        '"coordinate"',
        '"arguments"',
        '"method"',
        '"stdout"',
        '"stderr"',
        '"env"',
        "bundle_id:",
        "element_id:",
        "window_id:",
        "arguments:",
        "method:",
        "stdout:",
        "stderr:",
        "env:",
    )
    return any(marker in lowercased for marker in payload_markers)


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
        "authorization:",
        "api_key",
        "apikey",
        "x-api-key",
        "access token",
        "auth token",
        "bearer ",
        "password",
        "private key",
    )
    if any(fragment in lowercased for fragment in blocked_fragments):
        return True

    blocked_patterns = (
        r"(?:^|\s)/(?:tmp|var|etc|opt|usr|bin|sbin)/",
        r"[A-Za-z]:\\",
        r"(?i)\b(?:token|authorization|api[-_ ]?key|password|passwd|secret|session|cookie)\s*[:=]",
        r"(?i)\b[A-Z][A-Z0-9_]*(?:TOKEN|SECRET|KEY|PASSWORD|COOKIE)[A-Z0-9_]*\s*=",
        r"(?i)\bsk-[A-Za-z0-9_-]{20,}",
        r"(?i)\bgh[pousr]_[A-Za-z0-9_]{20,}",
        r"[A-Fa-f0-9]{32,}",
        r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}",
    )
    return any(re.search(pattern, title) for pattern in blocked_patterns)


def write_summary(path, transport, initialize, loaded, listed, thread_objects, read_count):
    summary = {
        "transport": transport,
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


def daemon_start_available():
    try:
        completed = subprocess.run(
            [CODEX_BIN, "app-server", "daemon", "start"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=DAEMON_START_TIMEOUT_SECONDS,
            check=False,
        )
        return completed.returncode == 0
    except subprocess.TimeoutExpired:
        return False


def transport_command(transport):
    if transport == "proxy":
        return [CODEX_BIN, "app-server", "proxy"]
    return [CODEX_BIN, "app-server", "--stdio"]


def run_transport(args, transport, report_transport):
    process = None
    try:
        process = subprocess.Popen(
            transport_command(transport),
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
            timeout=PROXY_INITIALIZE_TIMEOUT_SECONDS if transport == "proxy" else TIMEOUT_SECONDS,
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
            write_summary(args.summary_json, report_transport, initialize, loaded, listed, thread_objects, read_count)

        print(
            "Live app-server smoke passed: "
            f"transport={report_transport!r}, "
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
    finally:
        if process is not None:
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def run_once(args):
    if args.transport == "stdio":
        return run_transport(args, transport="stdio", report_transport="stdio")

    daemon_available = daemon_start_available()
    if args.transport == "proxy" and not daemon_available:
        raise SmokeFailure("daemon start did not complete before proxy smoke")

    if daemon_available:
        try:
            return run_transport(args, transport="proxy", report_transport="proxy")
        except TransientSmokeFailure as error:
            if error.request_id != 1 or args.transport == "proxy":
                raise
            print(
                f"Live app-server smoke proxy unavailable before initialize: {error}; falling back to direct stdio.",
                file=sys.stderr,
            )

    return run_transport(args, transport="stdio", report_transport="stdio-fallback" if daemon_available else "stdio")


def main():
    args = parse_args()
    attempts = max(1, args.attempts)
    last_transient_error = None

    for attempt in range(1, attempts + 1):
        try:
            return run_once(args)
        except FileNotFoundError:
            print(f"Codex binary not found: {CODEX_BIN}", file=sys.stderr)
            return 1
        except TransientSmokeFailure as error:
            last_transient_error = error
            if args.summary_json:
                try:
                    os.remove(args.summary_json)
                except FileNotFoundError:
                    pass
            if attempt < attempts:
                print(
                    f"Live app-server smoke transient failure on attempt {attempt}/{attempts}: {error}",
                    file=sys.stderr,
                )
                time.sleep(0.5 * attempt)
                continue
            break
        except SmokeFailure as error:
            print(f"Live app-server smoke failed: {error}", file=sys.stderr)
            return 1

    print(f"Live app-server smoke failed: {last_transient_error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
