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
- the production surface can stack up to four speech bubbles at once: one
  primary Mimo report plus up to three compact context bubbles, while the app
  tracks up to six Codex thread contexts internally for overflow reporting
- secondary thread bubbles use short context-row text such as
  `「資料整理」作業中`, omit the longer Mimo address phrase, and form a dynamic
  nearby bubble cloud so multiple Codex threads read as a playful compact
  reporting surface rather than a centered list; secondary bubbles do not use
  speech tails, while the primary report uses a soft rounded connector so
  hierarchy comes from size, proximity, and accent markers
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
  read chats when `thread/read` returns several items per thread
- `CodexSessionSummarizer` derives a small safe `workSummary` from sanitized
  user, assistant, plan, and reasoning item text, then propagates that topic to
  later tool/status/progress lines in the same thread. This lets Mimo say what
  Codex is working on, such as `「Mimo runtime QA」は作業内容の説明をテスト中だよ`
  or `「Mimo runtime QA」は作業内容の説明を確認してよさそうだよ`, without exposing raw
  commands, paths, deltas, model text, or secret-looking fragments.
- `CodexMimoDialoguePrompt` can use an ephemeral Codex app-server session to
  rewrite the already-sanitized chat title, state, activity kind, and
  `workSummary` into a warmer one-sentence Mimo bubble. The generated
  `mimoSpeech` is safety-checked again, cached, and throttled per chat, while
  the internal Mimo Codex session is filtered out of visible production bubbles.
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
- Visible production wording is chat-name first: deterministic and generated
  Mimo bubbles avoid forced `ご主人` prefixes, never expose `Codex Session`,
  `Codex Thread`, or raw `動作中・停止・レビュー可` labels, and normalize user-facing
  `スレッド` / `セッション` vocabulary to `チャット`.
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
- autonomous wandering is enabled by default; `MIMO_AUTONOMOUS_WINDOW_MOVEMENT=0`
  remains the explicit anchored override for users who need a fixed position
- the test-covered planner chooses visible-screen targets `100-280 pt` away,
  caps production speed at `34 pt/s` inside a `560 pt` home radius, and uses a
  60Hz time-based tween that moves smoothly without overshooting
- autonomous window movement rate-limits the actual frame origins sent to
  AppKit, using the controller's last-submitted origin instead of trusting
  `NSPanel.frame` to update synchronously every 60Hz tick. This prevents a stale
  or queued tween from catching up as a sudden high-speed jump
- autonomous wandering also has a stamina controller: movement drains
  stamina, high stamina keeps speed near the production cap, resting quickly
  recovers to full, and below 50% stamina Mimo may stop based on mood to show a
  resting action before running again; directional animation starts after `8 pt`
  of real displacement and then loops at `0.36s` per frame without sample-driven
  restarts. `e2e_autonomous_default_movement.sh` verifies the default-enabled
  path, and `e2e_autonomous_energy.sh` verifies the move-then-rest production
  path with a deterministic fast-drain environment
- Codex-backed Mimo speech uses a separate ephemeral app-server session created
  by `thread/start` and driven with sanitized `turn/start` prompts; the app
  filters that internal session out of visible bubbles, while
  `live_mimo_dialogue_smoke.py` verifies the live generation path without
  writing into user work sessions. The rewrite default is now `gpt-5.6-luna`
  with `effort=low`, while `MIMO_CODEX_DIALOGUE_MODEL` remains an explicit
  override for diagnostics. A global cadence gate allows one conversation-list
  reorganization every 30 minutes, with a short failure backoff; this bounds
  token use even when app-server notifications arrive continuously
- initial `thread/list` and `thread/read` hydration restores the public
  `createdAt`, `updatedAt`, `recencyAt`, and turn timestamps before visibility
  filtering. Active chats remain visible, while a completed chat stays in the
  reporting surface only during the recent window so Mimo can tell the user to
  review it, close it, or resume it when more work is needed. The companion
  never performs those user-side actions automatically
- production speech bubbles use a large primary report plus smaller nearby
  context notes instead of forcing the full panel width; primary Mimo speech now
  caps at 398pt, can grow to four lines, and `PetSpeechBubblePaginator` advances
  overlong Mimo speech as timed pages before the next chat update is shown
- generated proposal boards
  `desktop/MimoDesktopPet/design/ui-proposals/mimo-generated-bubble-layout-concepts-06.png`
  and
  `desktop/MimoDesktopPet/design/ui-proposals/mimo-generated-pocket-pile-convergence-07.png`
  drove the latest bubble layout convergence: Pocket Pile was selected over
  Orbit Bouquet and Soft Cascade, then refined into a chaotic-cute close pile
  that keeps secondary chat summaries near Mimo, avoids edge clipping, and
  overlaps without burying the active primary speech
- `desktop/MimoDesktopPet/design/ui-proposals/mimo-generated-secondary-bubble-card-concepts-08.png`
  records the follow-up convergence after video review: secondary context now
  follows the Nest Cards direction, using narrower card-like columns and up to
  two summary lines so adjacent chat summaries stop reading as long thin labels
  while a later video pass tightened their orbit so they stay near Mimo's
  primary speech instead of drifting toward the top edge
- `desktop/MimoDesktopPet/design/ui-proposals/mimo-pocket-pop-motion-board-09.png`
  records the current pocket-pop motion direction: the primary report is larger
  and connected softly to Mimo, while new note cards grow upward from Mimo's side
  and push older cards into a nearby irregular pile
- chat names are treated as primary user-facing information: formatter output
  keeps readable chat titles up to the shared title limit instead of shortening
  them before layout, and secondary chat bubbles render the title before a short
  two-line activity summary inside compact note-like cards
- production bubble transitions use stable visual slots rather than text-derived
  view identity: new bubbles fade and rise in, removed bubbles fade upward,
  stack changes spring into place, and text-only updates cross-fade inside the
  existing bubble to keep rapid Codex notification updates from feeling abrupt
- production Mimo speech now uses a fast typewriter reveal inside the bubble:
  status, focused-chat, and secondary-chat text appears character by character,
  while chat-title segments stay visible from the start so users can always see
  which chat Mimo is talking about; overflow notes remain instant for scanning
- completion and review-ready states are displayed as user-facing meaning such
  as `確認してよさそう` or `ひと段落`, not raw internal labels like
  `停止・レビュー可`; multi-bubble row offsets are also tightened so secondary
  chat bubbles read as a compact stack rather than separated status cards
- `package_release.sh` builds a versioned release app bundle, signs it with a
  `Developer ID Application` identity, creates and signs a DMG, writes a
  SHA-256 sidecar, and can submit/staple notarization when a notarytool keychain
  profile is supplied
- `version_and_notarize.sh` is the preferred release command: it validates a
  notary keychain profile or App Store Connect API key, runs pre-release checks,
  calls the package script with notarization, verifies the stapled DMG with
  Gatekeeper checks, and can create the `v<version>` tag plus GitHub release;
  the matching project-local Codex skill lives in `skills/mimo-release/SKILL.md`
- `desktop/MimoDesktopPet/docs/notarization-asc-api-key.md` documents the
  App Store Connect Team Key setup flow, the `.p8` handling boundary, and the
  API-key based release command without recording real credential values
- `.github/workflows/release-slack-notify.yml` posts deploy-success
  notifications from GitHub Actions when a GitHub Release is published; the
  formatted Slack Block Kit payload is generated by
  `desktop/MimoDesktopPet/script/build_release_slack_payload.py`, and setup is
  documented in `desktop/MimoDesktopPet/docs/release-slack-notification.md`

## 2026-07-11: Kataribe Stage Redesign

- The production message surface was redesigned from the historical Pocket Pile
  bubble cloud into the selected Kataribe Stage. One content-sized paper report
  stays close to Mimo; one to six named pastel chat charms remain visible in a
  separate identity rail.
- `desktop/MimoDesktopPet/design/message-blank-slate-workshop.md` records the
  blank-slate comparison and BDD contract. The selected visual reference is
  `desktop/MimoDesktopPet/design/ui-proposals/mimo-message-blank-slate-12-kataribe-stage.png`.
- Every report and charm opens its exact Codex chat. Safe titles fall back to the
  first user request from `thread/read(includeTurns: true)`, so generic internal
  names do not reach production UI.
- The charm rail now filters by activity: active/in-progress chats stay visible,
  and a chat that just stopped remains for `180s`; old idle history and
  title-only updates are omitted. `CodexConversationVisibilityPolicyTests` and
  the fake app-server E2E lock this selection behavior.
- Interaction hit testing now separates the character from the message surface:
  the current animation frame's alpha mask is the drag surface, rounded
  report/charm shapes only open a chat on click, and transparent sprite/panel
  pixels make the `NSPanel` ignore mouse events so the app below receives the
  pointer. Window-background dragging is disabled to prevent AppKit from
  reclaiming transparent clicks.
- Reports paginate at 64 characters in tight 128pt/184pt paper tiers and keep
  the chat name visible. The charm rail is bottom-anchored: each narrated chat
  is inserted below, pushes older charms upward, and never swaps in both
  directions. Visible charms now fill compact 29pt rows with 3pt separation;
  removing the former transparent 44pt placement slot eliminates the apparent
  dead space between messages. Ordinary
  narration changes wait until Mimo rests for 0.8 seconds, while action-required
  chats may interrupt. The complete stage remains visible while Mimo walks.
- Mimo speech sanitization removes technical tracking language such as
  `チャット状態` and exposes no raw animation state through accessibility.
- `e2e_conversation_movement.sh`, `e2e_overflow_thread_list.sh`, and the new
  `inspect_production_capture.swift --kataribe-stage` mode lock walking
  readability, six visible names, transparent corners, report proximity, and
  bottom-up flow and stable accessibility targets.

Local desktop captures from companion QA must stay out of the repository. Use
`/tmp` for runtime screenshots. The local fake E2E verifies app-server startup,
safe `workSummary` propagation, notification-driven Mimo narration, named charm
retention, action-required promotion, walking readability, transparent corners,
and thread reads. The six-chat E2E verifies one report plus six named
bottom-up charm slots with no overflow counter. Other E2Es continue to cover stamina,
daemon timeout, proxy fallback, empty/offline state, read timeout, reconnect,
single-instance behavior, and the production status menu.

The live read-only smoke is `desktop/MimoDesktopPet/script/live_app_server_smoke.py`;
the live dialogue smoke verifies generated speech; and
`desktop/MimoDesktopPet/script/live_app_presentation_smoke.sh` launches the real
app against the real app-server before capturing the production window.
For iterative visual review, `desktop/MimoDesktopPet/script/capture_video_review.sh`
writes a temporary mp4, contact sheet, 60Hz coordinate samples, and presentation
log under `/tmp`. Keep the generated review bundle out of the public repository.

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
