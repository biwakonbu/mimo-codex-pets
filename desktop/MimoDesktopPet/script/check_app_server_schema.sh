#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_PROTOCOL_SWIFT="$ROOT_DIR/Sources/MimoDesktopPetCore/CodexProtocol.swift"
TMP_DIR="$(mktemp -d /tmp/mimo-app-server-schema.XXXXXX)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

codex app-server generate-json-schema --out "$TMP_DIR" --experimental >/dev/null

require_pattern() {
  local file="$1"
  local pattern="$2"
  if ! grep -q "$pattern" "$TMP_DIR/$file"; then
    echo "schema missing pattern '$pattern' in $file" >&2
    exit 1
  fi
}

require_pattern "ClientRequest.json" '"initialize"'
require_pattern "v1/InitializeParams.json" '"clientInfo"'
require_pattern "v1/InitializeParams.json" '"experimentalApi"'
require_pattern "ClientRequest.json" '"thread/loaded/list"'
require_pattern "ClientRequest.json" '"thread/list"'
require_pattern "ClientRequest.json" '"thread/read"'

require_pattern "ServerNotification.json" '"thread/started"'
require_pattern "ServerNotification.json" '"thread/status/changed"'
require_pattern "ServerNotification.json" '"thread/name/updated"'
require_pattern "ServerNotification.json" '"thread/archived"'
require_pattern "ServerNotification.json" '"thread/closed"'
require_pattern "ServerNotification.json" '"thread/deleted"'
require_pattern "ServerNotification.json" '"thread/unarchived"'
require_pattern "ServerNotification.json" '"turn/started"'
require_pattern "ServerNotification.json" '"turn/completed"'
require_pattern "ServerNotification.json" '"turn/plan/updated"'
require_pattern "ServerNotification.json" '"item/started"'
require_pattern "ServerNotification.json" '"item/completed"'
require_pattern "ServerNotification.json" '"item/agentMessage/delta"'
require_pattern "ServerNotification.json" '"item/plan/delta"'
require_pattern "ServerNotification.json" '"item/reasoning/summaryPartAdded"'
require_pattern "ServerNotification.json" '"item/reasoning/summaryTextDelta"'
require_pattern "ServerNotification.json" '"item/reasoning/textDelta"'
require_pattern "ServerNotification.json" '"item/commandExecution/outputDelta"'
require_pattern "ServerNotification.json" '"item/commandExecution/terminalInteraction"'
require_pattern "ServerNotification.json" '"item/fileChange/outputDelta"'
require_pattern "ServerNotification.json" '"item/fileChange/patchUpdated"'
require_pattern "ServerNotification.json" '"item/mcpToolCall/progress"'
require_pattern "v2/ThreadStartedNotification.json" '"thread"'
require_pattern "v2/ItemStartedNotification.json" '"item"'
require_pattern "v2/ItemCompletedNotification.json" '"item"'
require_pattern "v2/AgentMessageDeltaNotification.json" '"delta"'
require_pattern "v2/PlanDeltaNotification.json" '"delta"'
require_pattern "v2/CommandExecutionOutputDeltaNotification.json" '"delta"'
require_pattern "v2/McpToolCallProgressNotification.json" '"message"'

require_pattern "v2/ThreadReadParams.json" '"threadId"'
require_pattern "v2/ThreadReadParams.json" '"includeTurns"'

require_pattern "v2/ThreadReadResponse.json" '"userMessage"'
require_pattern "v2/ThreadReadResponse.json" '"agentMessage"'
require_pattern "v2/ThreadReadResponse.json" '"plan"'
require_pattern "v2/ThreadReadResponse.json" '"reasoning"'
require_pattern "v2/ThreadReadResponse.json" '"commandExecution"'
require_pattern "v2/ThreadReadResponse.json" '"fileChange"'
require_pattern "v2/ThreadReadResponse.json" '"mcpToolCall"'
require_pattern "v2/ThreadReadResponse.json" '"dynamicToolCall"'
require_pattern "v2/ThreadReadResponse.json" '"webSearch"'
require_pattern "v2/ThreadReadResponse.json" '"action"'
require_pattern "v2/ThreadReadResponse.json" '"openPage"'
require_pattern "v2/ThreadReadResponse.json" '"findInPage"'
require_pattern "v2/ThreadReadResponse.json" '"listFiles"'
require_pattern "v2/ThreadReadResponse.json" '"read"'
require_pattern "v2/ThreadReadResponse.json" '"search"'
require_pattern "v2/ThreadReadResponse.json" '"imageView"'
require_pattern "v2/ThreadReadResponse.json" '"localImage"'
require_pattern "v2/ThreadReadResponse.json" '"imageGeneration"'
require_pattern "v2/ThreadReadResponse.json" '"skill"'
require_pattern "v2/ThreadReadResponse.json" '"mention"'
require_pattern "v2/ThreadReadResponse.json" '"contextCompaction"'

python3 - "$TMP_DIR" "$CODEX_PROTOCOL_SWIFT" <<'PY'
import json
import re
import sys
from pathlib import Path

schema_dir = Path(sys.argv[1])
swift_path = Path(sys.argv[2])
swift = swift_path.read_text(encoding="utf-8")
server_notification = (schema_dir / "ServerNotification.json").read_text(encoding="utf-8")
thread_status_changed = (schema_dir / "v2" / "ThreadStatusChangedNotification.json").read_text(encoding="utf-8")


def schema_json(relative_path):
    return json.loads((schema_dir / relative_path).read_text(encoding="utf-8"))


def require_required_fields(relative_path, fields):
    data = schema_json(relative_path)
    required = set(data.get("required", []))
    missing = [field for field in fields if field not in required]
    if missing:
        raise SystemExit(
            f"schema missing required field(s) in {relative_path}: {', '.join(missing)}"
        )


def enum_body(name):
    match = re.search(rf"enum\s+{re.escape(name)}[^{{]*\{{(?P<body>.*?)\n\}}", swift, re.S)
    if not match:
        raise SystemExit(f"Swift enum {name} not found in {swift_path}")
    return match.group("body")


def raw_string_cases(name):
    body = enum_body(name)
    cases = re.findall(r'case\s+\w+\s*=\s*"([^"]+)"', body)
    if not cases:
        raise SystemExit(f"Swift enum {name} had no raw string cases")
    return cases


def schema_notification_methods():
    data = schema_json("ServerNotification.json")
    methods = []
    for variant in data.get("oneOf", []):
        method_enum = (
            variant
            .get("properties", {})
            .get("method", {})
            .get("enum", [])
        )
        methods.extend(method_enum)
    if not methods:
        raise SystemExit("schema ServerNotification.json had no notification methods")
    return methods


def implicit_string_cases(name):
    body = enum_body(name)
    cases = re.findall(r"case\s+([A-Za-z_][A-Za-z0-9_]*)", body)
    if not cases:
        raise SystemExit(f"Swift enum {name} had no cases")
    return cases


def require_schema_text(schema_text, value, label):
    if value not in schema_text:
        raise SystemExit(f"schema missing Swift {label}: {value}")


schema_methods = schema_notification_methods()
handled_methods = raw_string_cases("CodexNotificationMethod")
ignored_methods = raw_string_cases("CodexIgnoredNotificationMethod")

duplicate_schema_methods = sorted(method for method in set(schema_methods) if schema_methods.count(method) > 1)
if duplicate_schema_methods:
    raise SystemExit(
        "schema ServerNotification.json duplicated notification method(s): "
        + ", ".join(duplicate_schema_methods)
    )

overlap = sorted(set(handled_methods).intersection(ignored_methods))
if overlap:
    raise SystemExit(
        "Swift notification method(s) are both handled and ignored: "
        + ", ".join(overlap)
    )

classified_methods = set(handled_methods).union(ignored_methods)
missing_from_swift = sorted(set(schema_methods) - classified_methods)
if missing_from_swift:
    raise SystemExit(
        "schema notification methods not classified by Swift client: "
        + ", ".join(missing_from_swift)
    )

extra_in_swift = sorted(classified_methods - set(schema_methods))
if extra_in_swift:
    raise SystemExit(
        "Swift notification methods not present in schema: "
        + ", ".join(extra_in_swift)
    )

for flag in implicit_string_cases("CodexThreadActiveFlag"):
    require_schema_text(thread_status_changed, f'"{flag}"', "CodexThreadActiveFlag")

for relative_path, fields in {
    "v2/ThreadStartedNotification.json": ["thread"],
    "v2/ThreadStatusChangedNotification.json": ["threadId", "status"],
    "v2/ThreadNameUpdatedNotification.json": ["threadId"],
    "v2/TurnStartedNotification.json": ["threadId", "turn"],
    "v2/TurnCompletedNotification.json": ["threadId", "turn"],
    "v2/TurnPlanUpdatedNotification.json": ["plan", "threadId", "turnId"],
    "v2/ItemStartedNotification.json": ["item", "threadId", "turnId"],
    "v2/ItemCompletedNotification.json": ["item", "threadId", "turnId"],
    "v2/AgentMessageDeltaNotification.json": ["delta", "itemId", "threadId", "turnId"],
    "v2/PlanDeltaNotification.json": ["delta", "itemId", "threadId", "turnId"],
    "v2/ReasoningSummaryPartAddedNotification.json": ["itemId", "summaryIndex", "threadId", "turnId"],
    "v2/ReasoningSummaryTextDeltaNotification.json": ["delta", "itemId", "summaryIndex", "threadId", "turnId"],
    "v2/ReasoningTextDeltaNotification.json": ["contentIndex", "delta", "itemId", "threadId", "turnId"],
    "v2/CommandExecutionOutputDeltaNotification.json": ["delta", "itemId", "threadId", "turnId"],
    "v2/TerminalInteractionNotification.json": ["itemId", "processId", "stdin", "threadId", "turnId"],
    "v2/FileChangeOutputDeltaNotification.json": ["delta", "itemId", "threadId", "turnId"],
    "v2/FileChangePatchUpdatedNotification.json": ["changes", "itemId", "threadId", "turnId"],
    "v2/McpToolCallProgressNotification.json": ["itemId", "message", "threadId", "turnId"],
}.items():
    require_required_fields(relative_path, fields)

print("Schema-to-client check passed: all server notifications are handled or intentionally ignored, and active flags are present.")
PY

echo "Schema check passed: required app-server methods, notification payload keys, classified client notification cases, and thread item types are present."
