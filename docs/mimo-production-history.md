# Mimo Production History

This document summarizes how Mimo was produced and the production decisions that should be preserved in future repairs.

## Original Creative Brief

The requested mascot was for a Discord meeting-minutes AI bot. The visual concept was a cute, approachable AI assistant that can represent:

- meeting notes
- summarization
- task extraction
- archive/search/share support
- friendly team companion behavior

The character was directed toward a childlike chibi robot-angel assistant, implemented as a fully non-sexual app-safe mascot:

- white/silver bob hair
- large blue eyes
- white tech coat with pale blue accents
- light robot parts, about 30% robot feel
- small angel wings
- small golden halo
- red randoseru backpack
- pen and tablet/notepad
- slightly floating stance

The source references were a character setting sheet, a proposal sheet, and an icon concept.

## User Quality Requirements Captured During Production

The important production requirements were:

- no chroma-key green left in object pixels
- no green in antialias pixels, highlights, shadows, reflections, halo, wings, hair, clothing, robot parts, backpack, pen, or tablet
- character edges must not look dirty or jagged
- add about a 3px white/light-blue edge so the character does not blend into green
- if the final style needs less visible edge, make the edge temporary and remove it only after key removal
- motion must be natural enough to feel present in Codex, not rough or mechanical
- verify the pet in actual Codex usage
- record live use and create review videos
- keep the result available in a public GitHub repository for future repair/regeneration

## Generation Approach

The workflow used the Codex `hatch-pet` process:

1. Use image generation for the base character and row strips.
2. Preserve Mimo's identity across all rows.
3. Build the Codex pet atlas deterministically.
4. Validate the final atlas and motion previews.
5. Package as `~/.codex/pets/mimo`.

The final package in this repository is:

- `pets/mimo/pet.json`
- `pets/mimo/spritesheet.webp`

## States

Mimo uses the Codex 9-row pet contract:

| Row | State | Frames | Intent |
| --- | --- | ---: | --- |
| 0 | `idle` | 6 | calm breathing and blink |
| 1 | `running-right` | 8 | rightward drag movement |
| 2 | `running-left` | 8 | leftward drag movement |
| 3 | `waving` | 4 | greeting gesture |
| 4 | `jumping` | 5 | playful hover/jump |
| 5 | `failed` | 8 | blocked/failed slump and recovery |
| 6 | `waiting` | 6 | waiting for user input |
| 7 | `running` | 6 | active task work, not literal running |
| 8 | `review` | 6 | quiet review/focus |

## Production Problems Found

The first valid atlas had clean enough basic transparency but the motion was too normalized:

- many frames were resized to almost the same full-cell height
- `jumping` looked like pose changes rather than vertical travel
- `failed` lost some slump/recovery amplitude
- all rows sat too close to the top and bottom cell boundaries

The issue was not primarily the image generation. The original generated jumping strip already had usable vertical travel. The issue was extraction/composition: per-frame fit-to-cell scaling had flattened the motion.

## Repair Strategy

The repair used deterministic reconstruction instead of regenerating all rows.

Key decisions:

- Start from the original generated row strips.
- Use connected component grouping to identify each frame in a row strip.
- Preserve shared row top/bottom bounds instead of independently resizing each frame.
- Compose frames into `192x208` cells with row-stable scale and position.
- Keep `running-left` as a mirror of `running-right` because identity and timing remain safe when mirrored.
- Add a translucent 3px `#F8FCFF` edge after clean extraction.
- Clamp green-dominant alpha-positive pixels.
- Normalize transparent RGB.
- Reject any cell-edge alpha.

This fixed the key motion problem:

- `jumping` now has real vertical center travel.
- `failed` keeps a lower slump frame and recovery.
- `idle`, `waiting`, and `review` remain calm and readable.

## Directional Running Repair

A later GIF review found two separate issues in `running-right` and `running-left`:

- the original generated row had a broken foot-transfer section where the lower legs collapsed inward mid-loop
- the first deterministic repair removed that defect by repeating clean frames, but it no longer read as natural running

The final repair regenerated `running-right` as a true 8-frame chibi gait row, then extracted the eight components through the same chroma/outline pipeline used by the rest of the pet. `running-left` was mirrored from the accepted `running-right` with frame order preserved.

Important lesson: for directional movement, smooth bbox metrics are not enough. The row must visibly alternate support foot and sending foot. A hover-step is acceptable only if the state intentionally wants floating movement; it should not be described as natural running.

The first regenerated gait still had two QA problems:

- the body/upper silhouette changed size between frames
- tiny disconnected alpha components remained around the character

An attempted cleanup stabilized the upper body by compositing it with lower-body motion from another pass. That approach was rejected because it made the sprite feel cut apart and increasingly unnatural.

The accepted correction is frame-planned full-body regeneration:

- define the intended pose of all 8 frames before generation in `docs/running-motion-storyboard.md`
- regenerate `running-right` as complete full-body frames
- allow only whole-sprite extraction, whole-sprite uniform scaling, baseline alignment, despill, and connected-component debris removal
- do not cut the body into upper/lower halves or freeze one part while changing another
- mirror the accepted full-body `running-right` into `running-left`
- require `non_main_area_total == 0` for directional running rows

After cleanup, the running rows have no disconnected sprite debris. Any remaining body-size variation must come from the generated full-body pose itself, not from local body-part stitching.

## Raw Source Preservation And Guard Outline

A later contact-sheet review found that the visible outer edge differed by row. The first attempted correction added a white outline directly to already-transparent atlas cells, but that was rejected because future repairs need to preserve the generated source images before spritesheet processing.

The accepted correction is source-based:

- preserve the selected generated row strips under `sources/mimo/generated-raw/`
- create `sources/mimo/chroma-guard/` from those raw strips before key removal
- make the chroma-guard strips use exact `#00FF00` background and a 3px `#F8FCFF` guard outline
- extract frames from the chroma-guard strips with `stable-slots`
- remove chroma, clamp green dominance, normalize boundary color, and normalize transparent RGB
- do not grow a new outline after transparency extraction

The `waiting` row was regenerated to better match the desired waiting behavior: blinking while gently floating. The regenerated raw strip is preserved as `sources/mimo/generated-raw/waiting.png`, and its prompt is preserved as `sources/mimo/prompts/waiting-floating.md`.

## QA Performed

Static QA:

- atlas size: `1536x1872`
- cell size: `192x208`
- unused cells: fully transparent
- `review.json`: errors `0`, warnings `0`
- `validation.json`: errors `0`, warnings `0`

Extra edge gates:

- `green_dominant_6_a_gt0 == 0`
- `green_dominant_16_low_alpha == 0`
- `close_key_alpha_gt0 == 0`
- `cell_edge_alpha == 0`
- `transparent_rgb_residue_pixels == 0`

When saving WebP, preserve normalized transparent pixels. Pillow WebP export should use lossless output with `exact=True`; otherwise fully transparent pixels can decode with non-zero hidden RGB residue even after the source image was normalized.

Visual QA:

- `assets/contact-sheet.png`
- `assets/previews/*.gif`
- `assets/demo-videos/mimo-state-grid.mp4`
- `assets/demo-videos/mimo-background-sweep.mp4`
- `assets/demo-videos/mimo-state-spotlight.mp4`

Live Codex QA:

- Mimo was installed under `~/.codex/pets/mimo`.
- Mimo was manually selected/displayed in Codex.
- Live recordings were created locally and reviewed.
- Live recordings were not committed because they show desktop/workspace context.

## Desktop Companion Production Notes

The SwiftPM macOS companion in `desktop/MimoDesktopPet` is intentionally separate from the Codex pet package. It reuses the same public Mimo atlas, but production runtime behavior is app-side:

- the default window is transparent and borderless
- the window uses macOS screen-saver level plus all-Spaces/fullscreen auxiliary
  behavior so Mimo stays above normal apps
- startup acquires a user-scoped single-instance lock before AppKit creates the
  panel, so duplicate launches exit without creating a second desktop pet
  window
- status and recent Codex activity are shown only as short speech-bubble text
- production speech bubbles summarize the current thread title and latest
  progress-like line as Mimo's report to the user instead of dumping speaker
  labels or tool output
- thread titles and raw conversation text pass through a shared
  ambient-display safety gate before production planning; instruction blocks,
  machine payloads, stdout/stderr/env fragments, local paths, bearer tokens,
  email addresses, and credential markers are replaced by safe generic activity
  rather than copied into bubbles
- the production bubble queue rotates the latest short report from each visible
  thread, deduplicating by thread, speaker, and sanitized text
- the production surface can stack up to five speech bubbles at once: one
  primary Mimo report plus up to four compact context bubbles, while the app
  tracks up to six Codex thread contexts internally for overflow reporting
- secondary thread bubbles use short context-row text such as
  `「資料整理」作業中`, omit the longer Mimo address phrase, and align into a
  centered stacked list so multiple Codex threads read as a compact reporting
  surface; only the primary Mimo report keeps a speech tail
- thread bubble text is rendered as a colored thread title plus a one-line Mimo
  report, so simultaneous bubbles are scan-friendly without becoming a
  transcript or debug feed
- the primary bubble uses the `focus` role when it is reporting a specific
  Codex thread, keeping generic `status` bubbles for idle/offline state and
  making the current thread visually distinct from secondary thread summaries
- when more tracked threads exist than visible context slots, the last compact
  bubble becomes a smaller `overflow` counter such as `ほか3件も見ています`
  instead of pretending that the hidden threads are concrete visible summaries
- every production bubble carries a semantic tone (`active`, `waiting`,
  `review`, `failed`, `overflow`, or `neutral`) that drives compact marker
  color/icon treatment and is logged as `bubbleTones` for E2E verification
- production bubbles also carry `bubbleActivityKinds`; ordinary active markers
  use those typed kinds to distinguish plan, command/test, file, browser,
  image, skill, mention, and status work without exposing raw payloads
- the stacked bubble list is rebuilt when conversation context changes, even
  when the primary timed bubble text is unchanged
- `item/started` and `item/completed` notifications enqueue sanitized
  tool/command progress immediately from their schema-backed `item` payloads
- streaming delta notifications are treated as activity signals and converted
  into generic Mimo reports without quoting raw delta strings
- the white conversation-feed panel is a `Debug Overlay` mode, not the
  production surface; its menu toggle is hidden unless `MIMO_DEBUG_MENU=1` or
  `MIMO_DEBUG_OVERLAY=1` is set
- Codex state is read through app-server JSON-RPC with schema-aligned
  `initialize.clientInfo` and `capabilities.experimentalApi`
- `codex app-server daemon start` is treated as a bounded best-effort helper for
  the preferred `codex app-server proxy` transport; a stuck daemon-start process,
  failed proxy launch, early proxy exit, or proxy handshake timeout falls back to
  direct stdio JSON-RPC instead of waiting forever
- the app reads `thread/loaded/list`, `thread/list(limit: 6)`, and
  `thread/read(includeTurns: true)` and sanitizes item text before display
- extracted conversation lines keep typed activity kinds for plan, reasoning,
  command, test, file, browser, image, skill, mention, and status updates, so
  production bubbles summarize the kind of Codex work before falling back to
  loose text matching
- live presentation smoke title expectations are checked against the same
  shared fixture cases as the Swift production title formatter, including
  machine payload and stdout/env marker titles, preventing the Python preflight
  helper from drifting away from production bubble behavior
- live app-server read-only smoke mirrors production transport selection with
  daemon start, proxy first, and direct stdio fallback before initialize; it
  retries transient response timeouts with a fresh selected transport, while
  preserving immediate failure for protocol errors and malformed responses
- `MIMO_CODEX_EXECUTABLE` is the app-specific override for deterministic
  manual QA and fake app-server runs; it takes precedence over the older
  generic `CODEX_BIN` override, which remains supported for existing scripts
- Computer Use is useful as an opportunistic UI observation channel, but it may
  fail to attach to the `LSUIElement` screen-saver-level companion
  (`remoteConnection` or `cgWindowNotFound`) and can disturb deterministic
  fake-app launches by starting the bundle through LaunchServices. Treat CGWindow capture,
  presentation logs, and production E2E scripts as the canonical visual QA
  evidence. Production E2E resolves the window by launched process PID via
  `script/find_mimo_window.swift`, so a stale or separately launched Mimo window
  cannot accidentally satisfy a screenshot gate.
- periodic refresh uses `thread/loaded/list` to re-read visible threads, so
  secondary thread bubbles can update after initial load
- `CodexConversationLineCombiner` preserves at least one representative line
  for every tracked visible thread before applying the internal conversation
  line cap, so multi-thread bubbles do not collapse to only the most recently
  read sessions when `thread/read` returns several items per thread
- `CodexSessionSummarizer` derives a small safe `workSummary` from sanitized
  user, assistant, plan, and reasoning item text, then propagates that topic to
  later tool/status/progress lines in the same thread. This lets Mimo say what
  Codex is working on, such as `吹き出し要約のテスト中`, without exposing raw
  commands, paths, deltas, model text, or secret-looking session fragments.
- production multi-thread bubbles use the same tested layered row offsets and
  subtle horizontal staggering in SwiftUI as the layout contract, keeping the
  focused Mimo report closest to the sprite while secondary thread summaries
  and overflow stay in compact rows that still read as separate bubbles
- `script/inspect_accessibility_surface.swift` checks the running app's macOS
  accessibility tree for `MimoDesktopPet.productionSurface`; empty-thread E2E
  verifies the idle production bubble and Mimo image node, while overflow E2E
  requires the multi-thread stack to expose stable per-bubble identifiers plus
  the overflow summary from the same surface Computer Use observes
- each production bubble is also exposed as a grouped accessibility element
  with a stable identifier such as
  `MimoDesktopPet.productionSurface.bubble.0.focus` and a label containing the
  full bubble text; primary-first sort priority keeps Mimo's main report ahead
  of secondary context and prevents accessibility clients from interleaving
  marker, title, and summary subviews across adjacent bubbles
- production accessibility E2Es reject debug-only bubble identifiers, labels,
  and debug mode values so the normal multi-bubble surface cannot quietly
  regress into the QA-only single speech bubble or conversation feed
- `check_app_bundle_contract.sh` verifies the built production bundle contract,
  including `LSUIElement=true`, bundle identity, executable permissions, and
  bundled Mimo pet resources, so the companion cannot quietly regress into a
  regular Dock/console-style app bundle
- refresh-cycle reads are coalesced across `thread/loaded/list` and
  `thread/list(limit: 6)`, so a tracked thread is read once per poll even when
  both list phases include it
- thread, turn, and item notifications also trigger an immediate
  `thread/read(includeTurns: true)` for the affected thread, keeping secondary
  bubble text fresh without waiting for the next poll
- non-initialize app-server requests have a watchdog timeout, so a live
  app-server process that stops answering `thread/read` cannot leave stale
  connected context onscreen; Mimo falls back to a transparent
  `Codex 接続タイムアウト` bubble
- startup failure, process disconnect, and request timeout offline states
  schedule app-server reconnection while the companion remains running, so a
  later healthy proxy or stdio session can restore connected thread-summary
  bubbles
  without restarting Mimo
- autonomous wandering uses a test-covered planner that chooses visible-screen
  targets, caps production speed at `52 pt/s`, limits each hop distance, and
  uses a 60Hz time-based tween that moves smoothly without overshooting
- autonomous wandering also has a stamina controller: movement drains stamina,
  high stamina keeps speed near the production cap, resting quickly recovers to
  full, and below 50% stamina Mimo may stop based on mood to show a resting
  action before running again; `e2e_autonomous_energy.sh` verifies the
  move-then-rest production path with a deterministic fast-drain environment

Local desktop captures from companion QA must stay out of the repository. Use `/tmp` for runtime screenshots. The local E2E smoke test is `desktop/MimoDesktopPet/script/e2e_fake_app_server.sh`; it verifies the fake app-server flow, app-server proxy startup, safe session-derived `workSummary` propagation, notification-driven and streaming-delta per-thread Mimo-style production bubble summaries, simultaneous multi-thread speech bubbles, secondary-thread notification refresh, semantic `bubbleTones`, typed `bubbleActivityKinds`, production window size, screen-saver window layer, smooth movement, transparent screenshot corners, and thread read calls. `desktop/MimoDesktopPet/script/e2e_autonomous_energy.sh` verifies that the stamina model can drain during autonomous movement, pause Mimo for a rest action, and keep the production surface transparent. `desktop/MimoDesktopPet/script/e2e_hanging_daemon_start.sh` verifies that a stuck daemon-start helper is timed out and does not prevent the companion from reaching stdio thread-context bubbles. `desktop/MimoDesktopPet/script/e2e_proxy_fallback_app_server.sh` verifies that a failed app-server proxy falls back to direct stdio while the production surface stays transparent. `desktop/MimoDesktopPet/script/e2e_empty_thread_list.sh` verifies that a connected empty thread list reaches the production idle bubble and exposes the same `MimoDesktopPet.productionSurface` accessibility box observed by Computer Use. `desktop/MimoDesktopPet/script/e2e_overflow_thread_list.sh` verifies that six tracked Codex threads still render as a bounded five-bubble stack with concrete activity kinds on visible thread bubbles, no activity kind on the compact overflow note, a multi-bubble visual hierarchy, and matching accessibility elements with stable per-bubble identifiers. `desktop/MimoDesktopPet/script/e2e_thread_read_timeout.sh` verifies that a hanging `thread/read` request leaves connected state and becomes a transparent timeout bubble instead of waiting forever. `desktop/MimoDesktopPet/script/e2e_reconnect_app_server.sh` verifies that a disconnected app-server can be reconnected and return to connected thread-summary bubbles without restarting the companion. `desktop/MimoDesktopPet/script/e2e_single_instance.sh` verifies that a duplicate launch exits without creating another desktop pet process/window while the first instance stays alive. `desktop/MimoDesktopPet/script/e2e_status_menu.sh` verifies that the production status menu keeps the debug overlay hidden unless debug mode is explicitly enabled and that Click Through / Debug Overlay menu checked states match the launch mode. `desktop/MimoDesktopPet/script/check_app_bundle_contract.sh` verifies that the staged `.app` is an `LSUIElement` menu-bar companion and contains executable Mimo assets before QA accepts the build. The live read-only app-server smoke test is `desktop/MimoDesktopPet/script/live_app_server_smoke.py`, which requests the same six-thread `thread/list` limit used by production and reads each returned candidate thread; `desktop/MimoDesktopPet/script/test_live_app_server_smoke_retry.sh` proves that transient response timeouts are retried against a fresh selected app-server transport, and `desktop/MimoDesktopPet/script/test_live_app_server_smoke_transport.sh` proves that the smoke helper uses proxy first and direct stdio fallback before initialize. The live app presentation smoke test is `desktop/MimoDesktopPet/script/live_app_presentation_smoke.sh`; it launches the real app with a temporary `/tmp` presentation log, verifies that the visible presentation leaves the offline/connection state after a real app-server connection, and when readable live threads exist, requires a production thread-context bubble with a sanitized title match and activity kind before capturing the window.

## Public Repository Decision

The public repository intentionally includes:

- pet package
- contact sheet
- GIF previews
- sprite-derived demo videos
- QA JSON
- production notes

The public repository intentionally excludes:

- live Codex screen recordings
- live screen thumbnails
- local desktop captures
- raw generated image cache
- temporary frame sequences

This preserves the pet and process without exposing local work context.
