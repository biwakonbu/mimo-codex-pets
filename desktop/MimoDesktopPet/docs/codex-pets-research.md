# Codex Pets Behavior Research

This companion aims to mimic the user-visible feel of Codex Pets without depending on Codex.app private internals.

## Current Evidence

Verified public protocol surface:

- `codex app-server generate-json-schema --experimental` exposes the client methods used by the companion:
  - `initialize`
  - `thread/loaded/list`
  - `thread/list`
  - `thread/read`
- The same schema exposes the server notifications used by the companion:
  - `thread/status/changed`
  - `turn/started`
  - `turn/completed`
  - `item/started`
  - `item/completed`
- `thread/read(includeTurns: true)` exposes recent `ThreadItem` values, including:
  - `userMessage`
  - `agentMessage`
  - `reasoning`
  - `commandExecution`
  - `fileChange`
  - `mcpToolCall`

Verified runtime behavior:

- `initialize` must include top-level `version: 1`; without it, the local app-server rejects the request.
- `codex app-server --stdio` returns a Codex Desktop user agent and can read local thread state.
- App-server responses and notifications may interleave on stdout; the client must dispatch by `method` vs `id`.
- `thread/list` can return no interactive threads; the companion must stay open and remain idle/offline-safe.

Computer Use limitation:

- Direct Computer Use inspection of `com.openai.codex` is blocked by safety policy in this environment.
- Companion QA can still use Computer Use on `MimoDesktopPet` and local screenshot/alpha inspection.

## Mimic Rules

Production mode:

- Keep the panel transparent and borderless.
- Show only Mimo and a speech bubble.
- Do not show a console, transcript feed, JSON payload, raw tool arguments, local paths, or long model output.
- Keep status and conversation text short enough to fit a two-line bubble.
- Use a debug-only overlay for feed-style inspection.

State behavior:

- active Codex work uses `running`.
- active work waiting on approval or user input uses `waiting`.
- failed turn or system error uses `failed`.
- recently completed assistant output uses `review`.
- no known active state uses `idle`.
- manual or autonomous movement uses directional `running-right` / `running-left` based on observed movement direction.

Conversation behavior:

- Prefer a fresh `agentMessage` or `userMessage` when available.
- Tool activity should be summarized, not dumped.
- Machine payload-looking text is suppressed and replaced with a generic short phrase.
- Bubble text is transient; durable feed display belongs only in `Debug Overlay`.

## Verification Gates

Run before accepting companion behavior changes:

```bash
cd desktop/MimoDesktopPet
swift test
./script/check_app_server_schema.sh
./script/e2e_fake_app_server.sh
./script/build_and_run.sh --verify
```

Manual or visual checks:

- Computer Use on `MimoDesktopPet` shows only speech bubble plus Mimo in production mode.
- Window capture corner alpha is transparent.
- `Debug Overlay` can be toggled from the menu and is not enabled by default.
- Temporary screenshots and logs stay under `/tmp` and are not committed.

## Open Research

The exact internal Codex Pets timing, text queue, and bubble heuristics cannot be confirmed through Computer Use in this environment because Codex.app inspection is blocked. Do not depend on Codex.app private bundle state for production behavior. Continue improving mimicry through public protocol evidence, generated schema checks, fake app-server scenarios, and direct companion QA.
