#!/usr/bin/env bash
set -euo pipefail

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

require_pattern "ServerNotification.json" '"thread/status/changed"'
require_pattern "ServerNotification.json" '"turn/started"'
require_pattern "ServerNotification.json" '"turn/completed"'
require_pattern "ServerNotification.json" '"item/started"'
require_pattern "ServerNotification.json" '"item/completed"'

require_pattern "v2/ThreadReadParams.json" '"threadId"'
require_pattern "v2/ThreadReadParams.json" '"includeTurns"'

require_pattern "v2/ThreadReadResponse.json" '"userMessage"'
require_pattern "v2/ThreadReadResponse.json" '"agentMessage"'
require_pattern "v2/ThreadReadResponse.json" '"reasoning"'
require_pattern "v2/ThreadReadResponse.json" '"commandExecution"'
require_pattern "v2/ThreadReadResponse.json" '"fileChange"'
require_pattern "v2/ThreadReadResponse.json" '"mcpToolCall"'

echo "Schema check passed: required app-server methods and thread item types are present."
