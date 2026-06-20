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
- `item/started` and `item/completed` notifications include a schema-backed
  `item` payload. Production bubbles use this to report in-progress tool or
  command activity before the next poll completes.
- Streaming notifications such as `item/agentMessage/delta`,
  `item/plan/delta`, `item/commandExecution/outputDelta`,
  `item/fileChange/outputDelta`, and `item/mcpToolCall/progress` exist in the
  generated schema. Production bubbles treat these as activity signals, not as
  text to quote directly.

Verified runtime behavior:

- `initialize` requires `clientInfo.name` and `clientInfo.version`; extra
  JSON-RPC `jsonrpc` fields are tolerated but not required.
- `codex app-server --stdio` returns a Codex Desktop user agent and can read local thread state.
- App-server responses and notifications may interleave on stdout; the client must dispatch by `method` vs `id`.
- `thread/list` can return no interactive threads; the companion must stay open and remain idle/offline-safe.
- The companion should periodically refresh visible threads, not only the
  currently selected thread, so stacked production bubbles keep following
  secondary thread progress after initial load.
- Thread, turn, and item notifications should also trigger an immediate
  `thread/read(includeTurns: true)` for the affected thread, so secondary
  thread bubbles do not wait for the next periodic poll.
- `codex app-server proxy` exists, but in this local environment it did not
  respond without changing daemon remote-control settings. The companion uses
  direct `codex app-server --stdio` to avoid mutating user configuration.

Computer Use limitation:

- Direct Computer Use inspection of `com.openai.codex` is blocked by safety policy in this environment.
- Companion QA can still use Computer Use on `MimoDesktopPet` and local screenshot/alpha inspection.

## Mimic Rules

Production mode:

- Keep the panel transparent and borderless.
- Keep the panel above other apps by using macOS screen-saver window level plus
  all-Spaces/fullscreen auxiliary collection behavior.
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
- autonomous movement uses a 60Hz time-based tween with smooth speed variation,
  rather than per-frame random speed changes.
- autonomous movement caps production speed at `52 pt/s`, limits each hop distance, and
  intentionally inserts rest/idle moments between hops.

Conversation behavior:

- Prefer a fresh `agentMessage` or `userMessage` when available.
- Production bubbles do not quote Codex speaker labels directly. They combine
  the thread title and the latest progress-like line into a short Mimo report to
  the user, such as `ご主人、「<title>」は作業を進めています`.
- The production bubble queue deduplicates by thread, speaker, and sanitized
  text, then rotates the latest short report from each visible thread instead of
  pinning only one focused thread forever.
- Production can show up to three stacked speech bubbles at once: one primary
  status/current-thread bubble plus compact summaries from other visible
  threads. This keeps Codex Pets-like multi-thread awareness in the production
  surface without rendering a console, transcript feed, or debug panel.
- The stacked bubble list refreshes whenever conversation context changes, even
  if the primary status bubble text is still showing a timed moment or an older
  queue item.
- `item/started` enqueues sanitized progress immediately, especially for tool
  and command activity.
- Delta notifications enqueue generic Mimo reports such as response drafting,
  plan updates, command output review, file-change review, or tool progress.
  Do not display raw delta strings in production bubbles.
- Tool activity should be summarized, not dumped.
- Machine payload-looking text is suppressed and replaced with a generic short phrase.
- Bubble text is transient; durable feed display belongs only in `Debug Overlay`.

## Verification Gates

Run before accepting companion behavior changes:

```bash
cd desktop/MimoDesktopPet
swift test
./script/check_app_server_schema.sh
./script/live_app_server_smoke.py
./script/live_app_presentation_smoke.sh
./script/e2e_fake_app_server.sh
./script/build_and_run.sh --verify
```

Manual or visual checks:

- Computer Use on `MimoDesktopPet` shows only speech bubble plus Mimo in production mode.
- Window capture corner alpha is transparent.
- Window capture reports the Mimo window at screen-saver layer.
- Fake app-server E2E samples the live window position during autonomous
  movement and rejects large per-sample jumps.
- Fake app-server E2E enables `MIMO_PRESENTATION_LOG` and verifies that
  production bubble text is a Mimo-style summary of the active thread title and
  latest progress/tool activity, including notification-driven tool activity and
  streaming delta activity, plus simultaneous stacked bubbles for a second
  visible thread and a later secondary-thread update discovered immediately
  from notification-triggered thread reads.
- `MIMO_PRESENTATION_LOG` includes both `bubbleText` and `bubbleTexts`; stacked
  bubble-only updates should be logged for deterministic E2E evidence.
- The same log includes `debugOverlay`; production E2E must keep it `false` so
  the transcript/feed panel remains opt-in debug UI.
- Live app presentation smoke launches the actual app process with a temporary
  presentation log and verifies that the UI state leaves offline/connection
  presentation after a real app-server connection.
- `Debug Overlay` can be toggled from the menu and is not enabled by default.
- Temporary screenshots and logs stay under `/tmp` and are not committed.

## Open Research

The exact internal Codex Pets timing, text queue, and bubble heuristics cannot be confirmed through Computer Use in this environment because Codex.app inspection is blocked. Do not depend on Codex.app private bundle state for production behavior. Continue improving mimicry through public protocol evidence, generated schema checks, fake app-server scenarios, and direct companion QA.
