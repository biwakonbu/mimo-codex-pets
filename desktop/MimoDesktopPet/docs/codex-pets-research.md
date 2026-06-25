# Codex Pets Behavior Research

This companion aims to mimic the user-visible feel of Codex Pets without depending on Codex.app private internals.

## Current Evidence

Verified public protocol surface:

- `codex app-server generate-json-schema --experimental` exposes the client methods used by the companion:
  - `initialize`
  - `thread/loaded/list`
  - `thread/list`
  - `thread/read`
  - `thread/start`
  - `turn/start`
- `script/check_app_server_schema.sh` regenerates this schema and verifies that
  every `ServerNotification` method in the generated schema is either handled
  by `CodexNotificationMethod` or explicitly classified as intentionally ignored
  by `CodexIgnoredNotificationMethod`, so client-side protocol coverage cannot
  silently drift from the public app-server surface. It also verifies
  `CodexThreadActiveFlag` cases and the required payload keys Mimo depends on
  for live bubble updates, including `threadId`, `turnId`, `itemId`, `delta`,
  `message`, `item`, `plan`, `diff`, `run`, `review`, `requestId`, and `goal`
  on the supported lifecycle and streaming notification shapes.
- The same schema exposes the server notifications used by the companion:
  - `thread/started`
  - `thread/status/changed`
  - `thread/name/updated`
  - `thread/goal/updated`
  - `thread/goal/cleared`
  - `thread/archived`
  - `thread/closed`
  - `thread/deleted`
  - `thread/unarchived`
  - `thread/compacted`
  - `hook/started`
  - `hook/completed`
  - `turn/started`
  - `turn/completed`
  - `turn/diff/updated`
  - `turn/moderationMetadata`
  - `item/started`
  - `item/completed`
  - `item/autoApprovalReview/started`
  - `item/autoApprovalReview/completed`
  - `serverRequest/resolved`
  - `mcpServer/startupStatus/updated`
  - `model/rerouted`
  - `model/verification`
  - `warning`
  - `guardianWarning`
  - `error`
- `thread/read(includeTurns: true)` exposes recent `ThreadItem` values, including:
  - `userMessage`
  - `agentMessage`
  - `plan`
  - `reasoning`
  - `commandExecution`
  - `fileChange`
  - `mcpToolCall`
  - `dynamicToolCall`
  - `collabAgentToolCall`
  - `subAgentActivity`
  - `webSearch`
  - `imageView`
  - `sleep`
  - `imageGeneration`
  - `enteredReviewMode`
  - `exitedReviewMode`
  - `contextCompaction`
- The same response schema includes nested activity shapes that production
  bubbles summarize without showing arguments: `webSearch.action.type` can be
  `search`, `openPage`, or `findInPage`; `commandExecution.command.type` can be
  `read`, `listFiles`, or `search`. These are treated as generic search, page,
  file, or command activity rather than exposing queries, URLs, paths, or raw
  commands.
- `item/started` and `item/completed` notifications include a schema-backed
  `item` payload. Production bubbles use this to report in-progress tool or
  command activity before the next poll completes.
- Streaming notifications such as `item/agentMessage/delta`,
  `item/plan/delta`, `turn/plan/updated`,
  `item/reasoning/summaryPartAdded`, `item/reasoning/summaryTextDelta`,
  `item/reasoning/textDelta`, `item/commandExecution/outputDelta`,
  `item/commandExecution/terminalInteraction`, `item/fileChange/outputDelta`,
  `item/fileChange/patchUpdated`, `item/mcpToolCall/progress`,
  `turn/diff/updated`, `item/autoApprovalReview/started`,
  `item/autoApprovalReview/completed`, `hook/started`, `hook/completed`,
  `serverRequest/resolved`, `thread/goal/updated`, and
  `thread/goal/cleared` exist in the generated schema. Thread-scoped system
  notifications such as `thread/compacted`, `model/rerouted`,
  `model/verification`, `turn/moderationMetadata`,
  `mcpServer/startupStatus/updated`, `warning`, `guardianWarning`, and `error`
  are also activity signals. Production bubbles do not quote their payloads
  directly. Terminal stdin, process ids, patch paths, patch diffs, hook run
  payloads, server request ids, approval actions/reasons, thread goal
  objectives, model names, reroute reasons, verification payloads, moderation
  metadata, warning/error text, and MCP server names are never displayed; Mimo
  reports only fixed summaries such as terminal input checking, diff checking,
  approval review, hook checking, confirmation reflection, goal checking,
  context compaction, model adjustment, safety checking, warning checking, or
  MCP status checking.
  Realtime transcript/audio notifications stay intentionally ignored in v1
  because they can contain raw transcript text or audio data.

Verified runtime behavior:

- `initialize` sends `clientInfo.name = "mimo_desktop_pet"`,
  `clientInfo.version`, and `capabilities.experimentalApi = true`; extra
  JSON-RPC `jsonrpc` fields are tolerated but not required.
- `codex app-server proxy` is the preferred companion transport after a bounded
  `codex app-server daemon start`. Direct `codex app-server --stdio` remains the
  fallback when daemon startup, proxy launch, or proxy handshake is unavailable.
  The direct stdio transport returns a Codex Desktop user agent and can read local
  thread state.
- Read-only live smoke checks use production-like `auto` transport selection:
  bounded daemon start, proxy first, then direct stdio fallback if proxy cannot
  initialize. Each attempt uses a fresh selected transport and retries transient
  response timeouts. This keeps the product gate resilient to momentary local
  Codex stalls while still failing immediately on protocol errors or malformed
  responses.
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
- For deterministic manual QA and fake app-server runs, the app and live smoke
  helper accept `MIMO_CODEX_EXECUTABLE` as a Mimo-specific command override.
  It takes precedence over the existing generic `CODEX_BIN` override, which is
  still supported for compatibility with older scripts.
- `codex app-server daemon start` is a bounded helper for the preferred proxy
  transport. If daemon startup hangs, proxy startup fails, proxy exits early, or
  proxy handshake times out, the companion should proceed to direct
  `codex app-server --stdio` JSON-RPC rather than leaving Mimo in a startup wait.
- The companion should periodically refresh visible threads, not only the
  currently selected thread, so stacked production bubbles keep following
  secondary thread progress after initial load.
- Thread, turn, and item notifications should also trigger an immediate
  `thread/read(includeTurns: true)` for the affected thread, so secondary
  thread bubbles do not wait for the next periodic poll.
- `thread/started` includes a schema-backed `thread` object. The companion
  should show that new thread as the focused conversation context immediately
  and still issue `thread/read(includeTurns: true)` so the cached thread body is
  refreshed before the next poll.
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
- The companion must not mutate daemon remote-control settings. It can try
  `daemon start` and `proxy`, but direct stdio fallback must remain available so
  production startup does not depend on private Codex.app state or user config
  changes.
- Mimo speech rewriting uses a separate ephemeral Codex session, not the user's
  active work session. The companion creates that internal session with
  `thread/start`, then asks for one short Mimo speech bubble with `turn/start`.
  The turn input contains only sanitized session title, state, activity kind,
  safe `workSummary`, and deterministic fallback text. It uses
  `approvalPolicy=never`, read-only sandbox policy, and empty environments so
  Codex is used as a text rewriter rather than as an agent that can inspect the
  workspace. The internal Mimo session is filtered out of visible thread lists,
  notification tracking, and production bubbles.
- `script/live_mimo_dialogue_smoke.py` exercises that same live app-server path
  without touching user work sessions: it creates an ephemeral Mimo session,
  sends a sanitized `turn/start` request, waits for assistant-message
  notifications, and rejects unsafe or non-Mimo speech.
- The production bubble panel intentionally uses nearly the full 432pt window
  width for primary Mimo speech and reserves a taller stack area for text. The
  primary bubble can render three lines, jitters only inside Mimo's near speech
  area, and keeps its speech tail pulled back toward Mimo when the bubble body
  shifts sideways. Secondary session rows can render two lines and scatter as a
  bounded irregular chat cloud near Mimo, while `PetSpeechBubblePaginator`
  splits longer Mimo speech into timed pages so conversation-sketch playback can
  continue without truncating the whole message into one chip.
- `design/ui-proposals/mimo-perfect-cute-ui-board-05.png` records the current
  cute UI direction generated from the Mimo identity prompt: soft organic white
  bubbles, pastel activity pins, tiny decorative pips, and a barely-there
  home-radius movement feel. Production SwiftUI uses those elements without
  adding readable decorative text or a separate dashboard panel.
- The production bubble panel treats each visible bubble identity as stable, but
  does not pin secondary summaries to a fixed row grid. Additions fade and rise
  from the primary/Mimo side, removals fade upward, stack-position changes use a
  short spring, and text-only updates cross-fade in place. This avoids the Codex
  status surface feeling like a hard-refreshing log panel when app-server
  notifications arrive close together.

Computer Use limitation:

- Direct Computer Use inspection of `com.openai.codex` is blocked by safety policy in this environment.
- Direct Computer Use app-state inspection of `MimoDesktopPet` may also fail for
  the production companion because it is an `LSUIElement` app using a
  non-activating screen-saver-level panel. This is a Computer Use attachment
  limitation, not proof that the panel is absent.
- The latest Computer Use rechecks reproduced both limitations:
  `com.openai.codex` was rejected by the Computer Use safety policy, and a
  running production `MimoDesktopPet` could not be attached reliably
  (`remoteConnection` in one run, `cgWindowNotFound` in a later run) instead of
  returning a useful accessibility tree.
- A later Computer Use recheck against `MimoDesktopPet` still returned only
  `remoteConnection`. During that manual attempt, Computer Use appeared to
  interact with the app through LaunchServices rather than preserving the
  shell-launched fake app-server environment, so deterministic fake-app visual
  QA should not depend on Computer Use attachment. Use Computer Use as an
  opportunistic observation channel only; use process-scoped CGWindow capture
  and presentation logs as the canonical evidence.
- Companion visual QA therefore uses CGWindow discovery plus
  `screencapture -l` on the exact Mimo window owned by the shell-launched app
  process. The capture is then inspected for transparent corners, bounded alpha
  coverage, white speech-bubble pixels, and Mimo sprite color pixels.
- The production surface still exposes a best-effort accessibility label,
  identifier, and value on its interaction view for assistive tooling that can
  attach to the window. That value is assembled only from the already-sanitized
  visible bubble texts, never from raw app-server payloads.

## Mimic Rules

Production mode:

- Keep the panel transparent and borderless.
- Keep the panel above other apps by using macOS screen-saver window level plus
  all-Spaces/fullscreen auxiliary collection behavior.
- Show only Mimo and speech bubbles.
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
- manual movement uses directional `running-right` / `running-left` based on
  observed movement direction.
- default production keeps the desktop panel anchored unless
  `MIMO_AUTONOMOUS_WINDOW_MOVEMENT=1` or a deterministic autonomous QA mode is
  set; Mimo's ambient life comes from in-place rest/idle moments and the dynamic
  nearby bubble cloud. Anchored mode schedules the first in-place moment after
  about `8s`, then uses a calm `18-34s` cadence so Mimo feels present without
  pacing around the desktop.
- opt-in autonomous window movement uses a 60Hz time-based tween with smooth
  speed variation, rather than per-frame random speed changes.
- opt-in autonomous movement caps production speed at `2.4 pt/s`, limits each
  tiny hop to `4 pt`, keeps production targets inside an `8 pt` home radius, and
  intentionally inserts rest/idle moments between hops. During conversation
  bubbles, Mimo holds position and uses in-place animation instead of moving the
  panel.
- Deterministic QA can pin the initial panel origin with
  `MIMO_WINDOW_ORIGIN=x,y`. Visual inspection runs may set
  `MIMO_AUTONOMOUS_DISABLED=1` to disable autonomous timers without changing the
  production default.

Conversation behavior:

- Prefer a fresh `agentMessage` or `userMessage` when available.
- Also synthesize short per-session activity lines from `thread/status/changed`,
  `turn/started`, `turn/completed`, `thread/list`, and `thread/read` state so a
  session can be reported even when recent item text is absent.
- Production bubbles do not quote Codex speaker labels directly. They combine
  the session title, latest progress-like line, and synthesized session state
  into a short Mimo report to the user, such as
  `ご主人、「<title>」は動作中で、作業を進めています`.
- Session titles are filtered for ambient display before they reach production
  bubbles. Instruction-looking titles, URLs, local paths, email addresses,
  token-like strings, and credential/secret markers are skipped; if another
  safe title or preview exists it is used, otherwise the bubble falls back to
  `Codex`.
- Raw conversation text uses the same ambient-display safety gate as thread
  titles before it can become a `CodexConversationLine`. Instruction blocks,
  JSON/YAML-like machine payloads, stdout/stderr/env fragments, local paths,
  bearer tokens, email addresses, and credential markers are replaced by short
  generic activity such as `応答を受信` or `ユーザー入力を受信` before bubble
  planning.
- Extracted conversation lines carry a typed activity kind such as plan,
  reasoning, command, test, file review, browser review, image generation,
  skill, mention, or thread status. The formatter uses that kind before loose
  text guessing, so Mimo can say `ファイルを確認中です` or `計画を整理中です`
  without relying on raw app-server payload wording or leaking tool arguments.
- Safe user, assistant, plan, and reasoning item text can also produce a compact
  `workSummary` through `CodexSessionSummarizer`. This is deliberately a small
  topic classifier rather than a transcript summarizer: it can identify themes
  such as `作業内容の説明`, `吹き出し要約の表示文言`,
  `進捗の具体説明`, `複数セッション表示`, `Codex 連携`, `セッション状況`,
  `画面確認`, or `Mimo の動き`, but it first applies the same ambient-display
  safety gate used for titles. Unsafe paths, credentials, stdout/env fragments,
  instruction-looking text, and other secret-looking session details therefore
  cannot become visible bubble topics.
- The latest safe `workSummary` and synthesized session activity state are propagated within that session to tool,
  command, file, status, review, and lifecycle progress lines. This lets Mimo
  explain both the work and the state, for example
  `ご主人、「Mimo runtime QA」は動作中で、作業内容の説明をテスト中です`,
  `ご主人、「Mimo runtime QA」は動作中で、吹き出し要約の表示文言をまとめています`,
  or `「Mimo runtime...」停止・進捗の具体説明レビュー可`, while still never quoting
  raw commands, paths, deltas, or model output.
- When Codex-backed Mimo speech is enabled, `CodexMimoDialoguePrompt` asks the
  ephemeral Mimo session to rewrite only those safe fields into a warmer
  one-sentence bubble. The generated `mimoSpeech` is safety-checked again before
  display and then cached by session title, state, activity kind, safe topic,
  and safe text. Regeneration is throttled per session so bubbles update at a
  human-readable cadence rather than streaming every raw Codex event.
- The live app presentation smoke uses Python to preflight expected sanitized
  title candidates. `check_title_sanitizer_parity.py` and
  `title_sanitizer_fixtures.json` keep that helper aligned with the Swift
  production formatter for safe, sensitive, instruction-looking,
  machine-payload, and stdout/env-marker titles, so live-smoke expectations do
  not drift from production bubble behavior.
- The production bubble queue deduplicates by thread and final Mimo report text,
  so multiple raw Codex events that summarize to the same short bubble do not
  make Mimo repeat itself. It then rotates the latest short report from each
  visible thread instead of pinning only one focused thread forever.
- The simultaneous production stack prioritizes thread coverage: secondary
  bubbles show at most one summary per thread, and if the primary bubble is
  already speaking for a conversation thread, that same thread is skipped in
  the secondary bubbles.
- The app-server client combines recent conversation lines with synthesized
  thread-status lines through `CodexConversationLineCombiner` before planner
  selection. When the internal line cap is hit, the combiner keeps at least one
  representative line for every tracked visible thread, then spends remaining
  line budget on focused-thread and recent-thread details. This keeps
  multi-thread bubbles from silently collapsing to only the most recently read
  sessions when `thread/read` returns several items per thread.
- When multiple threads compete for the stack, action-required states are
  promoted before ordinary work chatter: failure first, then confirmation
  waiting, then review-ready, then the existing preferred-thread/recency order.
- Production can show up to five speech bubbles at once: one primary
  status/focused-thread bubble plus compact summaries from other visible
  threads. The primary bubble stays lowest, widest, and visually attached to
  Mimo with the only speech tail. When it reports a focused conversation thread
  it uses the `focus` presentation role, a stronger accent marker, and the
  Mimo-style report for that session instead of a generic status such as
  `Codex が作業中`; idle/offline status keeps the simpler `status` role.
  Secondary session bubbles are smaller bounded context rows around it: they
  stay white, use compact accent markers, omit the longer `ご主人、...です`
  phrase, and use seeded organic offsets from `PetSpeechBubbleLayout`, so
  concurrent session status feels like a lively dynamic nearby bubble cloud
  without becoming a transcript panel. Bubble bodies use a soft organic shape
  rather than a strict rounded rectangle, secondary rows include tiny pastel
  pips, and the secondary width bounds keep short and long session titles
  readable while the placement stays intentionally irregular as Codex
  notifications arrive. Each organic placement also carries a tiny
  unsynchronized drift envelope, keeping the bubbles lightly in motion while the
  primary speech remains close enough to read as Mimo's own voice.
  This keeps Codex Pets-like multi-thread awareness in the production surface
  without rendering a console, transcript feed, or debug panel.
- Status bubbles are capped at 44 characters, focused-thread primary bubbles at
  48 characters, secondary thread rows at 34 characters, and overflow bubbles
  at 22 characters. Secondary bubbles render as one-line compact summaries such
  as `「資料整理」作業中` or `「承認」確認待ち`, so a five-bubble stack can show the
  primary Mimo report, three concrete thread rows, and one overflow counter
  without crowding or clipping Mimo. SwiftUI splits those thread bubble strings
  into a colored title segment and one-line Mimo summary at render time,
  preserving compact app-server logs while making simultaneous thread bubbles
  easier to scan visually. If more thread summaries are available than the remaining
  compact slots can show, Mimo keeps up to six thread contexts internally and
  reserves the final compact slot for a smaller overflow counter bubble such as
  `ほか2件も見ています` rather than silently dropping that extra context. If hidden
  contexts include attention states, the overflow bubble keeps the strongest
  hidden tone and switches to short wording such as `ほか3件に確認待ち`,
  `ほか3件に失敗あり`, or `ほか3件レビューあり`, so a compact stack does not
  flatten urgent hidden work into a neutral counter. The focus and overflow
  bubbles have their own `bubbleRoles` in presentation logs so E2E can
  distinguish a primary thread report from generic status and a concrete thread
  summary.
- Each production bubble also carries a semantic `bubbleTone` in presentation
  logs: `active`, `waiting`, `review`, `failed`, `overflow`, or `neutral`.
  SwiftUI uses the tone for compact state markers and accent color, while tests
  use it to verify that multiple thread bubbles are not just a flat text list.
- Production bubble logs also include `bubbleActivityKinds`, and SwiftUI uses
  those kinds for ordinary activity marker symbols when the tone is not a
  higher-priority failed/waiting/review/overflow state. This lets simultaneous
  thread bubbles distinguish plan, command/test, file, browser, image, skill,
  mention, and status work without showing raw commands or payload arguments.
- The same visible bubble text is exposed through the
  `MimoDesktopPet.productionSurface` interaction view's accessibility value
  when macOS accessibility tooling can attach to the panel. This makes
  screen-reader and Computer Use-visible text match the product bubble surface
  instead of introducing a second transcript channel.
- The multi-bubble production capture gate verifies more than raw bubble count:
  it requires visible white bubble components, a larger primary bubble closest
  to Mimo, a dynamic nearby bubble cloud with bounded irregular secondary
  placement, a single primary speech tail, no secondary tails, and one compact
  colored activity/state marker inside every bubble. This keeps the Codex
  Pets-style simultaneous thread surface from regressing into a flat transcript
  list, distant scattered cards, or anonymous white cards.
- The stacked bubble list refreshes whenever conversation context changes, even
  if the primary bubble text is still showing a timed moment or an older queue
  item.
- `item/started` enqueues sanitized progress immediately, especially for tool
  and command activity.
- Delta notifications enqueue generic Mimo reports such as response drafting,
  plan updates, reasoning summary updates, command output review, file-change
  review, or tool progress. Do not display raw delta strings in production
  bubbles.
- Secondary thread progress from notifications should be able to outrank a
  routine synthesized `作業中` status line, but static previews should not. If
  a secondary thread only has a preview plus active status, Mimo should keep the
  clearer active-status row. If a concrete notification arrives for that
  thread, such as diff, approval review, hook, server request, or goal progress,
  the notification summary should briefly replace the routine status row.
  The same applies to safe fixed summaries for context compaction, model
  rerouting/verification, moderation metadata, warnings, guardian warnings,
  errors, and MCP startup status.
- Command and tool-call items are sanitized before bubble planning. Command
  executions are reduced to `テストを実行中` or `コマンドを実行中`, and MCP or
  dynamic tool calls are reduced to `ツールを使用中`, so debug/feed state and
  production bubbles do not carry raw commands, tool names, paths, or
  arguments.
- Schema-shaped command and web actions get slightly more specific generic
  summaries: command `read` / `listFiles` / `search` actions become file or
  search review, while web `search` / `openPage` / `findInPage` actions become
  search or page review. The formatter still never shows the raw command, path,
  URL, query, or page pattern.
- Tool activity should be summarized, not dumped.
- Browser, file, image, skill, and mention activity should be reported as short
  generic activity such as page review, file review, image review, or skill
  review. Do not show raw URLs, file paths, search terms, skill names, thread
  identifiers, or tool arguments in production bubbles.
- Machine payload-looking text is suppressed and replaced with a generic short phrase.
- Bubble text is transient; durable feed display belongs only in `Debug Overlay`.
  The debug overlay menu item is hidden in production by default and is only
  exposed when `MIMO_DEBUG_MENU=1` or `MIMO_DEBUG_OVERLAY=1` is set.

## Verification Gates

Run before accepting companion behavior changes:

```bash
cd desktop/MimoDesktopPet
./script/qa_all.sh
```

`./script/qa_all.sh` is the canonical local gate. It runs the unit suite,
static syntax checks, README/research contract checks, generated app-server
schema drift checks, live app-server read/presentation smoke checks,
fake/content-length/proxy-fallback/empty-list/overflow/offline/disconnect/state-matrix
production E2E capture gates, and bundle verification. It also runs
`script/check_qa_all_coverage.py`, which fails if any `script/e2e_*.sh` file is
not present in both the shell-syntax check list and the canonical execution
steps. When a real Codex app-server is intentionally unavailable, run
`./script/qa_all.sh fake-only` and then rerun full mode before accepting
app-server integration changes.

`script/check_docs_contract.py` keeps this research note from becoming stale
documentation. It requires the README, this document, Swift app-server client,
Swift notification enums, live smoke helper, stamina controller/tests, and
canonical QA gate to keep the same public app-server transport, multi-bubble
mimicry, raw-payload safety, Computer Use limitation, production accessibility
surface, and autonomous stamina contract.

The full gate expands to:

```bash
swift test
./script/check_docs_contract.py
./script/check_app_server_schema.sh
./script/test_live_app_server_smoke_retry.sh
./script/test_live_app_server_smoke_transport.sh
./script/live_app_server_smoke.py
./script/live_app_presentation_smoke.sh
./script/e2e_fake_app_server.sh
./script/e2e_content_length_app_server.sh
./script/e2e_proxy_fallback_app_server.sh
./script/e2e_hanging_daemon_start.sh
./script/e2e_empty_thread_list.sh
./script/e2e_overflow_thread_list.sh
./script/e2e_thread_read_timeout.sh
./script/e2e_unavailable_app_server.sh
./script/e2e_disconnect_app_server.sh
./script/e2e_reconnect_app_server.sh
./script/e2e_single_instance.sh
./script/e2e_status_menu.sh
./script/e2e_state_matrix.sh
./script/build_and_run.sh --verify
```

Manual or visual checks:

- Computer Use should be attempted when available, but current production-window
  evidence comes from CGWindow discovery and `screencapture -l` because
  Computer Use may not attach to `LSUIElement` screen-saver-level panels. On
  2026-06-21, Computer Use returned only `remoteConnection` for
  `MimoDesktopPet`, and refused `com.openai.codex` for safety reasons, so
  current visual evidence remains CGWindow capture plus pixel inspection. If
  Computer Use is run during fake-app visual QA, verify that it has not replaced
  the shell-launched process with a LaunchServices-started instance before
  trusting the captured state.
- Window capture corner alpha is transparent.
- Window capture reports the Mimo window at screen-saver layer.
- Production E2E resolves the CGWindow through `script/find_mimo_window.swift`
  with the launched `APP_PID`, so a stale or LaunchServices-started Mimo window
  cannot satisfy the capture gate.
- `script/inspect_production_capture.swift` verifies that the captured
  production window is neither blank nor a debug-style opaque panel: it must
  contain transparent background, white speech-bubble pixels, and Mimo sprite
  color pixels.
- Multi-thread state captures additionally run
  `inspect_production_capture.swift --multi-bubble-hierarchy`, which segments
  white bubble components and verifies the visual hierarchy: the primary Mimo
  report must be widest, visually largest, closest to Mimo, and not buried by
  the secondary context bubbles. The same hierarchy check verifies that only the
  primary Mimo report has a speech tail; secondary thread context rows must stay
  tailless and within a nearby distance threshold. Secondary bubbles are allowed
  to overlap and vary in both axes, but they must not drift into distant cards,
  anonymous badges, or one unreadable merged white panel while still passing a
  raw bubble-count check.
- Fake app-server E2E samples the live window position during autonomous
  movement and rejects large per-sample jumps. Dedicated stationary E2E also
  verifies that conversation bubbles hold the panel still, while home-radius
  unit tests prevent long-term autonomous drift away from the user's chosen
  position.
- Fake app-server E2E enables `MIMO_PRESENTATION_LOG` and verifies that
  production bubble text is a Mimo-style summary of the active session title,
  safe session-derived `workSummary`, and latest progress/tool activity,
  including notification-driven tool activity and streaming delta activity, plus
  simultaneous stacked bubbles for a second visible session and a later
  secondary-session update discovered immediately from notification-triggered
  thread reads. The fake session specifically requires concrete topic-aware
  output such as `動作中で、吹き出し要約の表示文言をまとめています`,
  `動作中で、吹き出し要約の表示文言を計画中`, `動作中で、作業内容の説明をテスト中`, and
  `停止中で、作業内容の説明をレビューできます` so regression tests cover Mimo
  explaining what Codex is working on and whether the session is moving or
  stopped, not only generic state labels.
  The same fake E2E emits
  `thread/started` for a new session and verifies that Mimo reports the new
  session title and sends `thread/read` before the next polling cycle. The fake
  also keeps that started session out of subsequent list responses and verifies
  that Mimo retains the notification-discovered session in later production
  bubble refreshes instead of pruning it while list state catches up.
- Unit tests verify that extracted `CodexConversationLine` values retain typed
  activity kinds and that bubble summaries prefer those kinds over brittle raw
  text guesses, while failure text still overrides the kind.
- Fake app-server E2E also injects raw command/tool/delta, terminal-interaction,
  patch-update, turn-diff, approval-review, hook, server-request, thread-goal,
  model reroute/verification, moderation metadata, warning, guardian-warning,
  MCP startup-status, error, and sensitive conversation strings such as
  `swift test`, `get_app_state`, raw streaming text, bearer-token shaped text,
  password/stdout fragments, terminal stdin, patch diffs, process ids, hook run
  ids, approval actions, server request ids, goal objectives, model names,
  reroute reasons, verification payloads, moderation metadata, warning/error
  text, MCP server names, and local `.env` paths, then rejects any production
  bubble log that leaks those fragments.
- `MIMO_PRESENTATION_LOG` includes `bubbleText`, `bubbleTexts`, `bubbleRoles`,
  `bubbleTones`, `bubbleActivityKinds`, and `accessibilityValue`; stacked
  bubble-only updates should be logged for deterministic E2E evidence. Fake
  production E2E also enforces the five-bubble visible limit, the
  primary/secondary/overflow text-length caps, activity-kind marker propagation,
  accessibility value production-mode labeling, and a three-thread simultaneous
  bubble case with one focused primary bubble plus three conversation bubbles.
  Live app presentation smoke applies the same accessibility channel checks to
  real Codex app-server data: the value must mark production mode, mirror every
  visible bubble, and pass the same raw/sensitive-fragment leak gate as the
  rendered bubble text. The live gate also rejects generic ambient-unsafe
  shapes such as URLs, local paths, credential markers, long token-like
  strings, and email addresses, so the real app-server path is not weaker than
  fake leak scenarios.
  Overflow E2E separately verifies one focused primary bubble, three concrete
  conversation bubbles, and one overflow counter bubble with no activity kind
  on the counter.
- Primary bubble selection is not a transcript cursor. Mimo normally favors the
  focused Codex thread, but a failure, confirmation-waiting thread, or
  review-ready thread can take the primary report ahead of a merely active
  focused thread. The active focused thread remains as a secondary context row,
  which better matches the multi-thread companion role: Mimo reports the state
  that most needs the user's attention first.
- The same log includes `debugOverlay`; production E2E must keep it `false` so
  the transcript/feed panel remains opt-in debug UI. Production menu builds
  should not expose the debug toggle unless `MIMO_DEBUG_MENU=1` or
  `MIMO_DEBUG_OVERLAY=1` is set.
- Live app presentation smoke launches the actual app process with a temporary
  presentation log, verifies that the UI state leaves offline/connection
  presentation after a real app-server connection, and when the same live
  app-server exposes readable threads, requires a production `focus` or
  `conversation` bubble whose title matches a sanitized title candidate from
  that live thread context. It then captures the exact production window and
  runs `inspect_production_capture.swift` against it.
- Live app-server smoke retry check launches the live-smoke client against a
  fake stdio app-server that deliberately times out the first request path,
  then verifies that the second fresh app-server process succeeds and writes
  the expected summary JSON. This protects the full gate from one-shot local
  app-server stalls without hiding deterministic protocol failures.
- Live app-server smoke transport check launches the live-smoke client against a
  fake daemon/proxy-capable app-server, verifies that auto transport uses proxy
  when it initializes through the `MIMO_CODEX_EXECUTABLE` override, then forces
  proxy startup failure through the compatibility `CODEX_BIN` override and
  verifies direct stdio fallback before initialize.
- Proxy fallback E2E launches the app after a successful fake daemon start but
  forces `codex app-server proxy` to exit immediately. Mimo must then retry with
  direct `codex app-server --stdio`, reach connected thread-summary bubbles, and
  keep the transparent production surface.
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
- Single-instance E2E launches a connected Mimo process and then starts a
  second process with the same lock path. The second process must exit before
  creating a presentation log or a second screen-saver-level CGWindow, leaving
  the first transparent desktop pet alive. Tests use
  `MIMO_SINGLE_INSTANCE_LOCK_PATH` so the lock is isolated from any normal user
  launch.
- Status-menu E2E launches the real app process and reads the assembled menu
  via `MIMO_STATUS_MENU_LOG`. Production must expose Show/Hide, Click Through,
  Reconnect Codex, and Quit, must report Click Through as initially off, and
  must not expose `Debug Overlay`. Separate opt-in runs verify that
  `MIMO_DEBUG_MENU=1` and `MIMO_DEBUG_OVERLAY=1` both expose the debug item for
  development, and that `MIMO_DEBUG_OVERLAY=1` reports the debug item as
  checked.
- State-matrix E2E launches against the fake app-server with autonomous motion
  disabled, waits for active, waiting, simultaneous multi-thread, review, and
  failed presentation states, captures the exact production window for each
  state, runs `inspect_production_capture.swift` against every image, and
  applies the hierarchy check to the simultaneous multi-thread image.
- `Debug Overlay` can be toggled from the menu only when the debug menu is
  explicitly enabled, and is not enabled by default.
- Temporary screenshots and logs stay under `/tmp` and are not committed.

## Open Research

The exact internal Codex Pets timing, text queue, and bubble heuristics cannot be confirmed through Computer Use in this environment because Codex.app inspection is blocked. Do not depend on Codex.app private bundle state for production behavior. Continue improving mimicry through public protocol evidence, generated schema checks, fake app-server scenarios, and direct companion QA.
