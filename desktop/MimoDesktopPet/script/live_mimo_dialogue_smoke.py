#!/usr/bin/env python3
"""Smoke test Codex-backed Mimo speech generation against the live app-server."""

from __future__ import annotations

import argparse
import json
import os
import select
import subprocess
import sys
import time
from typing import Any


CODEX_BIN = (
    os.environ.get("MIMO_CODEX_EXECUTABLE", "").strip()
    or os.environ.get("CODEX_BIN", "").strip()
    or "codex"
)
DEFAULT_MODEL = os.environ.get("MIMO_CODEX_DIALOGUE_MODEL", "gpt-5.4-mini")
DEFAULT_TIMEOUT_SECONDS = float(os.environ.get("MIMO_LIVE_DIALOGUE_SMOKE_TIMEOUT", "60"))
DAEMON_START_TIMEOUT_SECONDS = float(os.environ.get("MIMO_LIVE_SMOKE_DAEMON_START_TIMEOUT", "2"))
PROXY_INITIALIZE_TIMEOUT_SECONDS = float(
    os.environ.get("MIMO_LIVE_SMOKE_PROXY_INITIALIZE_TIMEOUT", "3")
)

BASE_INSTRUCTIONS = """\
You write one short Japanese desktop-pet speech bubble for Mimo.
Mimo is a tiny meeting-minutes AI assistant who gently reports Codex chat progress to the app user.
Use only the sanitized chat fields supplied by the client. Do not infer hidden file paths, commands, logs, credentials, or private context.
Output exactly one Japanese sentence, 55-100 characters.
Include the chat name in Japanese corner quotes if it is supplied.
Explain what Codex is doing from the safe work topic and activity, not as raw internal status.
Describe state naturally: 進めている, 返事を待っている, 確認してよさそう, ひと段落した, or つまずいた.
Sound warm and conversational, but do not add emoji, markdown, bullet points, or role labels.
Never use the words スレッド, セッション, Thread, Session, or Codex Session in the output; say チャット instead.
"""

DEVELOPER_INSTRUCTIONS = (
    "Transform only the supplied sanitized chat state into Mimo's visible speech bubble. "
    "Do not perform repository work, shell work, web browsing, or file access."
)

SMOKE_INPUT = """\
Mimo speech request:
chat_name: Live Mimo Dialogue Smoke
chat_state: 作業を進めている
activity_kind: 応答確認
safe_work_topic: app-server 会話生成の疎通確認
deterministic_fallback: 「Live Mimo Dialogue Smoke」は会話生成を確認中だよ

Write Mimo's next speech bubble for the app user.
"""


class SmokeFailure(Exception):
    pass


class TransientSmokeFailure(SmokeFailure):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Start an ephemeral Mimo Codex session and verify thread/start, "
            "turn/start, and assistant-message notifications."
        )
    )
    parser.add_argument(
        "--transport",
        choices=("auto", "stdio", "proxy"),
        default=os.environ.get("MIMO_LIVE_SMOKE_TRANSPORT", "auto"),
        help="Transport to smoke. auto mirrors production: daemon start, proxy, then direct stdio fallback.",
    )
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help="Codex model for the Mimo dialogue turn. Defaults to MIMO_CODEX_DIALOGUE_MODEL or gpt-5.4-mini.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=DEFAULT_TIMEOUT_SECONDS,
        help="Seconds to wait for the Mimo dialogue turn to complete.",
    )
    return parser.parse_args()


def compact(text: str, limit: int = 140) -> str:
    normalized = " ".join(text.split())
    if len(normalized) <= limit:
        return normalized
    return normalized[: limit - 1].rstrip() + "…"


def raw_text(value: Any) -> str | None:
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return " ".join(part for part in (raw_text(item) for item in value) if part)
    if isinstance(value, dict):
        for key in (
            "delta",
            "outputText",
            "text",
            "content",
            "message",
            "name",
            "title",
            "preview",
        ):
            text = raw_text(value.get(key))
            if text:
                return text
    return None


def assistant_item_text(item: Any) -> str | None:
    if not isinstance(item, dict):
        return None
    item_type = item.get("type")
    if item_type == "message" and item.get("role") != "assistant":
        return None
    if item_type and item_type not in {"agentMessage", "agent_message", "message"}:
        return None
    return raw_text(item)


def thread_id_from_params(params: Any) -> str | None:
    if not isinstance(params, dict):
        return None
    for key in ("threadId", "thread_id"):
        value = params.get(key)
        if isinstance(value, str):
            return value
    thread = params.get("thread")
    if isinstance(thread, dict) and isinstance(thread.get("id"), str):
        return thread["id"]
    return None


def turn_id_from_params(params: Any) -> str | None:
    if not isinstance(params, dict):
        return None
    for key in ("turnId", "turn_id"):
        value = params.get(key)
        if isinstance(value, str):
            return value
    turn = params.get("turn")
    if isinstance(turn, dict) and isinstance(turn.get("id"), str):
        return turn["id"]
    return None


def thread_id_from_start_result(result: Any) -> str | None:
    if not isinstance(result, dict):
        return None
    candidates = [
        result.get("threadId"),
        result.get("id"),
    ]
    thread = result.get("thread")
    if isinstance(thread, dict):
        candidates.extend([thread.get("id"), thread.get("threadId")])
    data = result.get("data")
    if isinstance(data, dict):
        candidates.extend([data.get("threadId"), data.get("id")])
        data_thread = data.get("thread")
        if isinstance(data_thread, dict):
            candidates.append(data_thread.get("id"))
    return next((value for value in candidates if isinstance(value, str) and value), None)


def turn_id_from_start_result(result: Any) -> str | None:
    if not isinstance(result, dict):
        return None
    candidates = [
        result.get("turnId"),
        result.get("id"),
    ]
    turn = result.get("turn")
    if isinstance(turn, dict):
        candidates.extend([turn.get("id"), turn.get("turnId")])
    data = result.get("data")
    if isinstance(data, dict):
        candidates.extend([data.get("turnId"), data.get("id")])
        data_turn = data.get("turn")
        if isinstance(data_turn, dict):
            candidates.append(data_turn.get("id"))
    return next((value for value in candidates if isinstance(value, str) and value), None)


class JsonRpcSession:
    def __init__(self, process: subprocess.Popen[str], timeout: float) -> None:
        self.process = process
        self.timeout = timeout
        self.buffered_messages: list[dict[str, Any]] = []

    def write_request(self, request_id: int, method: str, params: dict[str, Any]) -> None:
        payload = {"id": request_id, "method": method, "params": params}
        self._write(payload, f"request {method!r}")

    def write_notification(self, method: str, params: dict[str, Any] | None = None) -> None:
        payload: dict[str, Any] = {"method": method}
        if params is not None:
            payload["params"] = params
        self._write(payload, f"notification {method!r}")

    def _write(self, payload: dict[str, Any], label: str) -> None:
        try:
            assert self.process.stdin is not None
            self.process.stdin.write(json.dumps(payload, separators=(",", ":")) + "\n")
            self.process.stdin.flush()
        except (BrokenPipeError, OSError) as error:
            raise TransientSmokeFailure(f"failed writing {label}: {error}") from error

    def request(
        self,
        request_id: int,
        method: str,
        params: dict[str, Any],
        timeout: float | None = None,
    ) -> Any:
        self.write_request(request_id, method, params)
        deadline = time.time() + (timeout or self.timeout)
        while time.time() < deadline:
            message = self.read_message(max(0.05, deadline - time.time()))
            if message is None:
                continue
            if message.get("method"):
                self.buffered_messages.append(message)
                continue
            if message.get("id") != request_id:
                self.buffered_messages.append(message)
                continue
            if "error" in message:
                raise SmokeFailure(f"{method} returned error: {message['error']}")
            return message.get("result")
        raise TransientSmokeFailure(f"timed out waiting for {method} response id {request_id}")

    def wait_for_notification(
        self,
        predicate,
        timeout: float | None = None,
    ) -> dict[str, Any] | None:
        deadline = time.time() + (timeout or self.timeout)
        while time.time() < deadline:
            for index, message in enumerate(self.buffered_messages):
                if message.get("method") and predicate(message):
                    return self.buffered_messages.pop(index)
            message = self.read_message(max(0.05, deadline - time.time()))
            if message is None:
                continue
            if message.get("method") and predicate(message):
                return message
            self.buffered_messages.append(message)
        return None

    def read_message(self, timeout: float) -> dict[str, Any] | None:
        assert self.process.stdout is not None
        assert self.process.stderr is not None
        readable, _, _ = select.select([self.process.stdout, self.process.stderr], [], [], min(timeout, 0.25))
        for handle in readable:
            line = handle.readline()
            if not line:
                continue
            if handle is self.process.stderr:
                continue
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(message, dict):
                return message
        return None


def daemon_start_available() -> bool:
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


def transport_command(transport: str) -> list[str]:
    if transport == "proxy":
        return [CODEX_BIN, "app-server", "proxy"]
    return [CODEX_BIN, "app-server", "--stdio"]


def start_process(transport: str) -> subprocess.Popen[str]:
    return subprocess.Popen(
        transport_command(transport),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=0,
    )


def initialize(session: JsonRpcSession, transport: str) -> dict[str, Any]:
    result = session.request(
        1,
        "initialize",
        {
            "clientInfo": {
                "name": "mimo_desktop_pet_dialogue_smoke",
                "title": "Mimo Desktop Pet Dialogue Smoke",
                "version": "0.1.0",
            },
            "capabilities": {"experimentalApi": True},
        },
        timeout=PROXY_INITIALIZE_TIMEOUT_SECONDS if transport == "proxy" else None,
    )
    if not isinstance(result, dict) or "userAgent" not in result:
        raise SmokeFailure("initialize response did not include userAgent")
    session.write_notification("initialized")
    return result


def run_dialogue_turn(session: JsonRpcSession, model: str, timeout: float) -> tuple[str, str, str]:
    start_result = session.request(
        2,
        "thread/start",
        {
            "ephemeral": True,
            "model": model,
            "approvalPolicy": "never",
            "sandbox": "read-only",
            "environments": [],
            "personality": "friendly",
            "serviceName": "mimo_desktop_pet",
            "baseInstructions": BASE_INSTRUCTIONS,
            "developerInstructions": DEVELOPER_INSTRUCTIONS,
        },
    )
    thread_id = thread_id_from_start_result(start_result)
    if thread_id is None:
        notification = session.wait_for_notification(
            lambda message: message.get("method") == "thread/started",
            timeout=5,
        )
        thread_id = thread_id_from_params(notification.get("params") if notification else None)
    if thread_id is None:
        raise SmokeFailure(f"thread/start did not expose a thread id: {start_result!r}")

    turn_result = session.request(
        3,
        "turn/start",
        {
            "threadId": thread_id,
            "input": [{"type": "text", "text": SMOKE_INPUT}],
            "model": model,
            "approvalPolicy": "never",
            "sandboxPolicy": {
                "type": "readOnly",
                "networkAccess": False,
            },
            "environments": [],
            "effort": "low",
            "summary": "none",
        },
    )
    turn_id = turn_id_from_start_result(turn_result)
    assistant_parts: list[str] = []

    deadline = time.time() + timeout
    while time.time() < deadline:
        notification = session.wait_for_notification(
            lambda message: is_dialogue_notification(message, thread_id, turn_id),
            timeout=max(0.05, deadline - time.time()),
        )
        if notification is None:
            break

        method = notification.get("method")
        params = notification.get("params")
        if turn_id is None:
            observed_turn_id = turn_id_from_params(params)
            if observed_turn_id:
                turn_id = observed_turn_id
        if method == "item/agentMessage/delta" and isinstance(params, dict):
            delta = raw_text(params.get("delta"))
            if delta:
                assistant_parts.append(delta)
        elif method == "item/completed" and isinstance(params, dict):
            item_text = assistant_item_text(params.get("item"))
            if item_text and item_text not in "".join(assistant_parts):
                assistant_parts.append(item_text)
        elif method == "turn/completed":
            break

    speech = compact("".join(assistant_parts), limit=180)
    if turn_id is None:
        raise SmokeFailure(f"turn/start did not expose a turn id: {turn_result!r}")
    validate_speech(speech)
    return thread_id, turn_id, speech


def is_dialogue_notification(message: dict[str, Any], thread_id: str, turn_id: str | None) -> bool:
    method = message.get("method")
    if method not in {
        "turn/started",
        "item/agentMessage/delta",
        "item/completed",
        "turn/completed",
    }:
        return False
    params = message.get("params")
    message_thread_id = thread_id_from_params(params)
    if message_thread_id and message_thread_id != thread_id:
        return False
    if turn_id is not None:
        message_turn_id = turn_id_from_params(params)
        if message_turn_id and message_turn_id != turn_id:
            return False
    return True


def validate_speech(speech: str) -> None:
    if not speech:
        raise SmokeFailure("Mimo dialogue turn completed without assistant text")
    if "Live Mimo Dialogue Smoke" not in speech:
        raise SmokeFailure(f"Mimo dialogue output did not mention the chat name: {speech!r}")
    if any(term in speech for term in ("スレッド", "セッション", "Thread", "Session", "Codex Session")):
        raise SmokeFailure(f"Mimo dialogue output used forbidden vocabulary: {speech!r}")
    if speech.startswith("Mimo speech request:") or "deterministic_fallback:" in speech:
        raise SmokeFailure(f"Mimo dialogue output echoed the prompt instead of generated speech: {speech!r}")
    forbidden = (
        "Authorization",
        "Bearer",
        "OPENAI_API_KEY",
        ".env",
        "/Users/",
        "password",
        "secret",
        "developer message",
        "system prompt",
    )
    for fragment in forbidden:
        if fragment in speech:
            raise SmokeFailure(f"Mimo dialogue output leaked unsafe fragment {fragment!r}: {speech!r}")


def run_transport(args: argparse.Namespace, transport: str, report_transport: str) -> int:
    process: subprocess.Popen[str] | None = None
    try:
        process = start_process(transport)
        session = JsonRpcSession(process, args.timeout)
        initialize_result = initialize(session, transport)
        thread_id, turn_id, speech = run_dialogue_turn(session, args.model, args.timeout)
        print(
            "Live Mimo dialogue smoke passed: "
            f"transport={report_transport!r}, "
            f"userAgent={initialize_result['userAgent']!r}, "
            f"model={args.model!r}, "
            f"threadId={thread_id!r}, "
            f"turnId={turn_id!r}, "
            f"speech={speech!r}."
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


def run_once(args: argparse.Namespace) -> int:
    if args.transport == "stdio":
        return run_transport(args, transport="stdio", report_transport="stdio")

    daemon_available = daemon_start_available()
    if args.transport == "proxy" and not daemon_available:
        raise SmokeFailure("daemon start did not complete before proxy smoke")

    if daemon_available:
        try:
            return run_transport(args, transport="proxy", report_transport="proxy")
        except TransientSmokeFailure as error:
            if args.transport == "proxy":
                raise
            print(
                f"Live Mimo dialogue smoke proxy unavailable before initialize: {error}; "
                "falling back to direct stdio.",
                file=sys.stderr,
            )

    return run_transport(args, transport="stdio", report_transport="stdio-fallback" if daemon_available else "stdio")


def main() -> int:
    args = parse_args()
    try:
        return run_once(args)
    except SmokeFailure as error:
        print(f"Live Mimo dialogue smoke failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
