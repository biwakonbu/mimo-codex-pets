# Codex Pets Behavior Research

This companion aims to mimic the user-visible feel of Codex Pets without depending on Codex.app private internals.

## Current Evidence

Verified public protocol surface:

- `codex app-server generate-json-schema --experimental` exposes the client methods used by the companion:
  - `initialize`
  - `thread/loaded/list`
  - `thread/list`
  - `thread/read`
- `script/check_app_server_schema.sh` regenerates this schema and verifies that
  the Swift `CodexNotificationMethod` and `CodexThreadActiveFlag` cases are
  still present in the schema, so client-side protocol coverage cannot silently
  drift from the public app-server surface.
- The same schema exposes the server notifications used by the companion:
  - `thread/status/changed`
  - `thread/name/updated`
  - `thread/archived`
  - `thread/closed`
  - `thread/deleted`
  - `thread/unarchived`
  - `turn/started`
  - `turn/completed`
  - `item/started`
  - `item/completed`
- `thread/read(includeTurns: true)` exposes recent `ThreadItem` values, including:
  - `userMessage`
  - `agentMessage`
  - `plan`
  - `reasoning`
  - `commandExecution`
  - `fileChange`
  - `mcpToolCall`
  - `dynamicToolCall`
  - `webSearch`
  - `openPage`
  - `findInPage`
  - `listFiles`
  - `read`
  - `search`
  - `imageView`
  - `localImage`
  - `imageGeneration`
  - `skill`
  - `mention`
  - `contextCompaction`
- `item/started` and `item/completed` notifications include a schema-backed
  `item` payload. Production bubbles use this to report in-progress tool or
  command activity before the next poll completes.
- Streaming notifications such as `item/agentMessage/delta`,
  `item/plan/delta`, `turn/plan/updated`,
  `item/reasoning/summaryPartAdded`, `item/reasoning/summaryTextDelta`,
  `item/reasoning/textDelta`, `item/commandExecution/outputDelta`,
  `item/fileChange/outputDelta`, and `item/mcpToolCall/progress` exist in the
  generated schema. Production bubbles treat these as activity signals, not as
  text to quote directly.

Verified runtime behavior:

- `initialize` requires `clientInfo.name` and `clientInfo.version`; extra
  JSON-RPC `jsonrpc` fields are tolerated but not required.
- `codex app-server --stdio` returns a Codex Desktop user agent and can read local thread state.
- App-server responses and notifications may interleave on stdout; the client must dispatch by `method` vs `id`.
- The client accepts both newline-delimited JSON and `Content-Length` JSON-RPC
  response framing. It auto-detects `Content-Length` on stdout and switches
  subsequent writes to the same framing, while keeping newline JSON as the
  default first write for the current `--stdio` app-server.
- App-server enum-like fields may grow over time. Unknown thread active flags
  are ignored, unknown turn statuses are treated as in-progress, and missing
  thread status defaults to idle so one protocol addition does not make Mimo
  stop reporting every visible thread.
- `thread/list` can return no interactive threads; the companion must stay open
  and emit a connected idle `待機中` presentation rather than lingering in
  connection-waiting/offline state or preserving stale thread bubbles.
- When the local Codex command or app-server is unavailable, the companion must
  stay open in transparent production mode and show a short offline bubble
  instead of crashing or revealing a debug surface.
- The companion should periodically refresh visible threads, not only the
  currently selected thread, so stacked production bubbles keep following
  secondary thread progress after initial load.
- Thread, turn, and item notifications should also trigger an immediate
  `thread/read(includeTurns: true)` for the affected thread, so secondary
  thread bubbles do not wait for the next periodic poll.
- Periodic refresh should coalesce `thread/read(includeTurns: true)` requests
  across the `thread/loaded/list` and `thread/list` phases so each tracked
  thread is read at most once per refresh cycle. Notification-triggered reads
  are still sent immediately so live activity does not wait for the next poll.
- Thread status alone is useful user-visible activity. A visible thread with no
  new item text should still be able to produce a short title + state report
  such as active work, confirmation waiting, review available, or failure.
- Thread name updates should retitle already visible conversation summaries.
  Thread archived, closed, or deleted notifications must remove that thread's
  cached title and bubble text immediately so stale bubbles do not linger.
- `codex app-server proxy` exists, but in this local environment it did not
  respond without changing daemon remote-control settings. The companion uses
  direct `codex app-server --stdio` to avoid mutating user configuration.

Computer Use limitation:

- Direct Computer Use inspection of `com.openai.codex` is blocked by safety policy in this environment.
- Direct Computer Use app-state inspection of `MimoDesktopPet` may also fail for
  the production companion because it is an `LSUIElement` app using a
  non-activating screen-saver-level panel. This is a Computer Use attachment
  limitation, not proof that the panel is absent.
- The latest Computer Use recheck reproduced both limitations: `com.openai.codex`
  was rejected by the Computer Use safety policy, and a running production
  `MimoDesktopPet` returned only a `remoteConnection` marker instead of a useful
  accessibility tree.
- Companion visual QA therefore uses CGWindow discovery plus
  `screencapture -l` on the exact Mimo window. The capture is then inspected for
  transparent corners, bounded alpha coverage, white speech-bubble pixels, and
  Mimo sprite color pixels.

## Mimic Rules

Production mode:

- Keep the panel transparent and borderless.
- Keep the panel above other apps by using macOS screen-saver window level plus
  all-Spaces/fullscreen auxiliary collection behavior.
- Show only Mimo and a speech bubble.
- Do not show a console, transcript feed, JSON payload, raw tool arguments, local paths, or long model output.
- Keep status and conversation text short enough to fit a two-line bubble.
- Use a debug-only overlay for feed-style inspection. Production startup must
  keep it disabled unless `MIMO_DEBUG_OVERLAY=1` is set or the menu item is
  toggled manually.

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
- Deterministic QA can pin the initial panel origin with
  `MIMO_WINDOW_ORIGIN=x,y`. Visual inspection runs may set
  `MIMO_AUTONOMOUS_DISABLED=1` to keep the pet stationary without changing the
  production default.

Conversation behavior:

- Prefer a fresh `agentMessage` or `userMessage` when available.
- Also synthesize short per-thread activity lines from `thread/status/changed`,
  `turn/started`, `turn/completed`, `thread/list`, and `thread/read` state so a
  thread can be reported even when recent item text is absent.
- Production bubbles do not quote Codex speaker labels directly. They combine
  the thread title and the latest progress-like line into a short Mimo report to
  the user, such as `ご主人、「<title>」は作業を進めています`.
- Thread titles are filtered for ambient display before they reach production
  bubbles. Instruction-looking titles, URLs, local paths, email addresses,
  token-like strings, and credential/secret markers are skipped; if another
  safe title or preview exists it is used, otherwise the bubble falls back to
  `Codex`.
- The production bubble queue deduplicates by thread and final Mimo report text,
  so multiple raw Codex events that summarize to the same short bubble do not
  make Mimo repeat itself. It then rotates the latest short report from each
  visible thread instead of pinning only one focused thread forever.
- The simultaneous production stack prioritizes thread coverage: secondary
  bubbles show at most one summary per thread, and if the primary bubble is
  already speaking for a conversation thread, that same thread is skipped in
  the secondary bubbles.
- When multiple threads compete for the stack, action-required states are
  promoted before ordinary work chatter: failure first, then confirmation
  waiting, then review-ready, then the existing preferred-thread/recency order.
- Production can show up to four fanned speech bubbles at once: one primary
  current-thread/status bubble plus up to three compact summaries from other
  visible threads. The primary bubble stays lowest, widest, and visually
  attached to Mimo with the only speech tail. Secondary thread bubbles are
  smaller context notes above it: they stay white, use compact accent markers,
  and alternate left/right placement so concurrent thread status is readable
  without becoming a feed panel. When a focused conversation line is available,
  the primary bubble uses that Mimo-style thread report instead of a generic
  status such as `Codex が作業中`; offline status keeps the generic connection
  bubble. This keeps Codex Pets-like multi-thread awareness in the production
  surface without rendering a console, transcript feed, or debug panel.
- The primary production bubble is capped at 44 characters, secondary thread
  bubbles at 34 characters, and overflow bubbles at 22 characters. Secondary
  bubbles render as one-line compact summaries so a four-bubble stack does not
  crowd or clip Mimo. If more thread summaries are available than the remaining
  compact slots can show, Mimo keeps up to six thread contexts internally and
  reserves the final compact slot for a smaller overflow counter bubble such as
  `ほか3件も見ています` rather than silently dropping that extra context. The
  overflow bubble has its own `overflow` role in presentation logs so E2E can
  distinguish it from a concrete thread summary.
- The stacked bubble list refreshes whenever conversation context changes, even
  if the primary status bubble text is still showing a timed moment or an older
  queue item.
- `item/started` enqueues sanitized progress immediately, especially for tool
  and command activity.
- Delta notifications enqueue generic Mimo reports such as response drafting,
  plan updates, reasoning summary updates, command output review, file-change
  review, or tool progress. Do not display raw delta strings in production
  bubbles.
- Command and tool-call items are sanitized before bubble planning. Command
  executions are reduced to `テストを実行中` or `コマンドを実行中`, and MCP or
  dynamic tool calls are reduced to `ツールを使用中`, so debug/feed state and
  production bubbles do not carry raw commands, tool names, paths, or
  arguments.
- Tool activity should be summarized, not dumped.
- Browser, file, image, skill, and mention activity should be reported as short
  generic activity such as page review, file review, image review, or skill
  review. Do not show raw URLs, file paths, search terms, skill names, thread
  identifiers, or tool arguments in production bubbles.
- Machine payload-looking text is suppressed and replaced with a generic short phrase.
- Bubble text is transient; durable feed display belongs only in `Debug Overlay`.

## Verification Gates

Run before accepting companion behavior changes:

```bash
cd desktop/MimoDesktopPet
./script/qa_all.sh
```

`./script/qa_all.sh` is the canonical local gate. It runs the unit suite,
static syntax checks, generated app-server schema drift checks, live app-server
read/presentation smoke checks, fake/content-length/empty-list/overflow/offline/disconnect/state-matrix
production E2E capture gates, and bundle verification. When a real Codex app-server is
intentionally unavailable, run `./script/qa_all.sh fake-only` and then rerun full
mode before accepting app-server integration changes.

The full gate expands to:

```bash
swift test
./script/check_app_server_schema.sh
./script/live_app_server_smoke.py
./script/live_app_presentation_smoke.sh
./script/e2e_fake_app_server.sh
./script/e2e_content_length_app_server.sh
./script/e2e_empty_thread_list.sh
./script/e2e_overflow_thread_list.sh
./script/e2e_thread_read_timeout.sh
./script/e2e_unavailable_app_server.sh
./script/e2e_disconnect_app_server.sh
./script/e2e_reconnect_app_server.sh
./script/e2e_state_matrix.sh
./script/build_and_run.sh --verify
```

Manual or visual checks:

- Computer Use should be attempted when available, but current production-window
  evidence comes from CGWindow discovery and `screencapture -l` because
  Computer Use may not attach to `LSUIElement` screen-saver-level panels. On
  2026-06-21, Computer Use returned only `remoteConnection` for
  `MimoDesktopPet`, and refused `com.openai.codex` for safety reasons, so
  current visual evidence remains CGWindow capture plus pixel inspection.
- Window capture corner alpha is transparent.
- Window capture reports the Mimo window at screen-saver layer.
- `script/inspect_production_capture.swift` verifies that the captured
  production window is neither blank nor a debug-style opaque panel: it must
  contain transparent background, white speech-bubble pixels, and Mimo sprite
  color pixels.
- Multi-thread state captures additionally run
  `inspect_production_capture.swift --multi-bubble-hierarchy`, which segments
  white bubble components and verifies exactly four bubble surfaces: the
  primary Mimo report must be widest, visually largest, and separated below the
  three secondary context bubbles.
- Fake app-server E2E samples the live window position during autonomous
  movement and rejects large per-sample jumps.
- Fake app-server E2E enables `MIMO_PRESENTATION_LOG` and verifies that
  production bubble text is a Mimo-style summary of the active thread title and
  latest progress/tool activity, including notification-driven tool activity and
  streaming delta activity, plus simultaneous stacked bubbles for a second
  visible thread and a later secondary-thread update discovered immediately
  from notification-triggered thread reads.
- Fake app-server E2E also injects raw command/tool/delta strings such as
  `swift test`, `get_app_state`, and raw streaming text, then rejects any
  production bubble log that leaks those fragments.
- `MIMO_PRESENTATION_LOG` includes `bubbleText`, `bubbleTexts`, and
  `bubbleRoles`; stacked bubble-only updates should be logged for deterministic
  E2E evidence. Fake production E2E also enforces the four-bubble visible
  limit, the primary/secondary/overflow text-length caps, and a three-thread
  simultaneous bubble case with one status bubble plus three conversation
  bubbles. Overflow E2E separately verifies one status bubble, two concrete
  conversation bubbles, and one overflow counter bubble.
- The same log includes `debugOverlay`; production E2E must keep it `false` so
  the transcript/feed panel remains opt-in debug UI.
- Live app presentation smoke launches the actual app process with a temporary
  presentation log, verifies that the UI state leaves offline/connection
  presentation after a real app-server connection, then captures the exact
  production window and runs `inspect_production_capture.swift` against it.
- Disconnect E2E launches against a fake app-server that reaches a connected
  thread-summary state and then exits. Mimo must stay alive, keep the production
  surface transparent, and show `Codex 接続切れ` instead of leaving stale
  connected bubbles onscreen.
- Thread-read timeout E2E launches against a fake app-server that initializes,
  returns list data, and then deliberately never responds to `thread/read`.
  Mimo must first show the connected thread summary, then clear stale connected
  context and show `Codex 接続タイムアウト` in the transparent production
  bubble. Production defaults to a 12-second request timeout; tests can shorten
  this with `MIMO_APP_SERVER_REQUEST_TIMEOUT`.
- Reconnect E2E launches against a fake app-server that disconnects after the
  first successful `thread/read` and then serves a different recovered thread
  snapshot on the next stdio session. Mimo must show the initial connected
  summary, then the offline `Codex 接続切れ` bubble, then reconnect without app
  restart and show the recovered thread summary. Production defaults to a
  4-second reconnect delay; tests can shorten this with
  `MIMO_APP_SERVER_RECONNECT_DELAY`.
- State-matrix E2E launches against the fake app-server with autonomous motion
  disabled, waits for active, waiting, simultaneous multi-thread, review, and
  failed presentation states, captures the exact production window for each
  state, runs `inspect_production_capture.swift` against every image, and
  applies the hierarchy check to the simultaneous multi-thread image.
- `Debug Overlay` can be toggled from the menu and is not enabled by default.
- Temporary screenshots and logs stay under `/tmp` and are not committed.

## Open Research

The exact internal Codex Pets timing, text queue, and bubble heuristics cannot be confirmed through Computer Use in this environment because Codex.app inspection is blocked. Do not depend on Codex.app private bundle state for production behavior. Continue improving mimicry through public protocol evidence, generated schema checks, fake app-server scenarios, and direct companion QA.
