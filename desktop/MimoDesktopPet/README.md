# Mimo Desktop Pet

Mimo Desktop Pet is a small macOS companion app that reuses the public Mimo
Codex pet package from this repository.

The v1 app keeps user work sessions read-only:

- it renders `../../pets/mimo/pet.json` and `../../pets/mimo/spritesheet.webp`
- it shows Mimo in a transparent floating desktop panel
- it keeps the panel at macOS screen-saver window level so Mimo stays above
  other apps, across Spaces and fullscreen apps
- it maps Codex app-server thread state to Mimo animation states
- it presents sanitized multi-thread updates through one narration surface in
  the Kataribe Stage and one to six named chat charms
- the report stays close to Mimo while every monitored chat remains identifiable
  and clickable; distinct pastel accents and unsynchronized breathing keep the
  identity rail lively without turning it into a transcript panel
- it derives a safe `workSummary` from session items with
  `CodexSessionSummarizer`, then lets Mimo explain the current work in its own
  short report style
- it can use a separate ephemeral Codex session to rewrite that already
  sanitized state into a warmer Mimo speech bubble
- it does not send prompts into the user's active work sessions, speak audio,
  inspect the screen, or read Codex session JSONL files

## Run

```bash
cd desktop/MimoDesktopPet
./script/build_and_run.sh
```

Useful checks:

```bash
./script/qa_all.sh
swift test
./script/check_app_server_schema.sh
./script/check_docs_contract.py
./script/check_app_bundle_contract.sh
./script/live_app_server_smoke.py
./script/live_app_presentation_smoke.sh
./script/build_and_run.sh --verify
./script/e2e_fake_app_server.sh
./script/e2e_unavailable_app_server.sh
./script/e2e_disconnect_app_server.sh
./script/e2e_state_matrix.sh
```

## Release Packaging

Build a signed release DMG without notarization:

```bash
./script/package_release.sh 0.0.1
```

The script builds the release binary, stages `dist/release/v0.0.1/MimoDesktopPet.app`,
signs it with the first available `Developer ID Application` identity, creates
`dist/release/v0.0.1/MimoDesktopPet-0.0.1.dmg`, signs the DMG, and writes a
SHA-256 sidecar file. The staged app bundle includes the Mimo pet package and
`Resources/AppIcon.icns`.

To notarize and staple the DMG, first store Apple notary credentials in the
keychain with `xcrun notarytool store-credentials`, then run:

```bash
./script/package_release.sh 0.0.1 --notarize --notary-profile <profile>
```

Without notarization, the DMG can still be attached to a GitHub release, but
macOS Gatekeeper may warn users when opening an internet-downloaded copy.

You can also notarize without Apple ID login prompts by using an App Store
Connect API key. Create/download a team API key from App Store Connect, keep the
`.p8` file outside this repository, then pass its key path, key ID, and issuer
ID. See `docs/notarization-asc-api-key.md` for the step-by-step setup flow and
the safety boundary for handling `.p8` files:

```bash
./script/package_release.sh 0.0.1 --notarize \
  --asc-key /secure/path/AuthKey_XXXXXXXXXX.p8 \
  --asc-key-id XXXXXXXXXX \
  --asc-issuer <issuer-uuid>
```

For the normal release path, use the versioned notarization wrapper:

```bash
./script/version_and_notarize.sh 0.0.1 --notary-profile MimoDesktopPet
```

The wrapper validates the clean worktree, runs pre-release checks, builds and
notarizes the DMG, staples the ticket, and verifies the final artifact with
`hdiutil`, `codesign`, `spctl`, and the SHA-256 sidecar. Add
`--github-release` after the notary profile when the notarized DMG should also
be tagged, pushed, and attached to a GitHub release. The project-local Codex
skill for this flow is `skills/mimo-release/SKILL.md`.

When a GitHub Release is published, `.github/workflows/release-slack-notify.yml`
can post a polished deploy-success notification to the `#mimo-desktop` Slack
channel. Configure the `MIMO_DESKTOP_SLACK_WEBHOOK_URL` GitHub Actions secret
first; see `docs/release-slack-notification.md`.

The same wrapper accepts App Store Connect API key flags:

```bash
./script/version_and_notarize.sh 0.0.1 \
  --asc-key /secure/path/AuthKey_XXXXXXXXXX.p8 \
  --asc-key-id XXXXXXXXXX \
  --asc-issuer <issuer-uuid> \
  --github-release
```

`./script/qa_all.sh` is the pre-acceptance gate for companion behavior changes.
It runs unit tests, static checks, schema/live app-server smoke checks, and all
production E2E capture gates. It also verifies that every `script/e2e_*.sh`
file is wired into the canonical gate, so new production E2E coverage cannot be
added and then silently skipped. Use `./script/qa_all.sh fake-only` only when a
real Codex app-server is intentionally unavailable.

`./script/build_and_run.sh` stages a local app bundle under
`dist/MimoDesktopPet.app`, launches it with `/usr/bin/open -n`, and sets
`MIMO_PET_PACKAGE_DIR` to this repository's `pets/mimo` package unless you
override it. In `--verify` mode it only checks that the staged bundle can
launch, then terminates the verification process so later E2E gates do not race
the single-instance lock.

Codex state sync initializes with `clientInfo.name = mimo_desktop_pet` and
`capabilities.experimentalApi = true`, then reads public app-server thread
state through `thread/loaded/list`, `thread/list`, and
`thread/read(includeTurns: true)`. It reacts to thread/turn/item lifecycle
notifications such as `thread/status/changed`, `turn/started`,
`turn/completed`, `item/started`, and `item/completed` to refresh visible
conversation bubbles promptly. For optional Mimo speech rewriting, the client
uses public `thread/start` and `turn/start` on a separate ephemeral Codex
session with `approvalPolicy=never`, read-only sandbox policy, and empty
environments. Only sanitized session title, state, activity kind, and
`workSummary` are sent to that internal Mimo session; raw commands, paths, logs,
or model output are not forwarded. Startup tries `codex app-server daemon start`
as a best-effort helper with a short timeout, then connects over JSON-RPC
through `codex app-server proxy`. If the daemon helper hangs, proxy startup
fails, or the proxy does not complete the handshake, the companion falls back to
direct `codex app-server --stdio`. If the local Codex app-server cannot be
launched, the companion stays open and shows an offline/waiting status instead
of crashing or waiting forever.
For deterministic manual QA, set `MIMO_CODEX_EXECUTABLE=/path/to/fake-codex`
to point the app and smoke helper at a fake app-server command. The older
`CODEX_BIN` override remains supported for existing scripts, but the Mimo-specific
override takes precedence when both are present.
Mimo speech rewriting is enabled in normal app launches and disabled by default
in `MIMO_BUBBLE_TEST_MODE=1`. Set `MIMO_CODEX_DIALOGUE_DISABLED=1` to force the
deterministic formatter, `MIMO_CODEX_DIALOGUE_ENABLED=1` to force Codex-backed
speech in tests, or `MIMO_CODEX_DIALOGUE_MODEL=gpt-5.6-terra` to override the
Codex model. The production default is `gpt-5.6-luna` with `effort=low` for the
short latency-sensitive rewrite turn. `MIMO_CODEX_DIALOGUE_REFRESH_SECONDS=45`
controls the per-session regeneration cadence.
Production bubbles use a large primary report card plus smaller nearby context
notes instead of forcing the full panel width. The primary bubble can grow to
four text lines, jitters only within Mimo's near speech area, and uses a soft
rounded connector rather than a sharp arrow tail.
Secondary session rows keep a bounded title/summary shape but scatter as a
nearby irregular chat cloud, so simultaneous Codex sessions feel alive instead
of fixed to a stacked grid. The current cute UI direction is tracked in
`design/ui-proposals/mimo-perfect-cute-ui-board-05.png`, with the current motion
staging in `design/ui-proposals/mimo-pocket-pop-motion-board-09.png`; production
follows them with a pocket-pop motion, soft organic bubble shapes, pastel
activity pins, small scrapbook tape marks on context notes, and tiny decorative
pips instead of hard rectangular cards. Overlong Mimo speech is split into
readable pages that advance on the same timed conversation-sketch loop as normal
session updates.
Bubble changes preserve each bubble identity while new bubbles grow and rise in
from the Mimo side, removed bubbles fade upward, stack position
changes use a short spring, and text-only updates cross-fade inside the existing
bubble instead of replacing the whole surface abruptly.
`./script/live_app_server_smoke.py` performs the same read-only initialize,
loaded-list, thread-list, and thread-read calls against the local app-server.
By default it mirrors production transport selection: bounded daemon start,
proxy first, then direct stdio fallback if proxy cannot initialize. It retries
transient response timeouts with a fresh selected transport so momentary local
Codex stalls do not make the full gate flaky; protocol errors still fail
immediately.
`./script/live_mimo_dialogue_smoke.py` performs the Mimo speech generation path
against the live app-server. It starts a separate ephemeral Mimo Codex session
with `thread/start`, sends one sanitized `turn/start` request with
`approvalPolicy=never`, read-only sandbox policy, and empty environments, then
waits for assistant-message notifications and verifies the generated bubble can
be shown as Mimo speech. Its default request uses `gpt-5.6-luna` with
`effort=low`, matching production. This smoke does not write into the user's
active work sessions.
`./script/check_app_server_schema.sh` verifies the generated app-server schema
and cross-checks that every server notification is either handled by the Swift
client or explicitly classified as intentionally ignored. It also keeps the
thread active flags schema-backed.
`./script/check_docs_contract.py` verifies that README, the Codex Pets research
notes, the Swift protocol/client, the live smoke helper, the stamina controller,
and the canonical QA gate still describe the same public app-server, production
bubble, and autonomous stamina behavior.
`./script/check_title_sanitizer_parity.py` verifies that the live smoke helper
and Swift production formatter keep the same ambient title sanitization behavior
for safe, unsafe, instruction-looking, machine-payload, stdout/env-marker,
nested, and fallback session titles.
`./script/check_app_bundle_contract.sh` builds and verifies the production app
bundle contract: `LSUIElement=true`, the menu-bar companion bundle identity, the
executable bit, and bundled Mimo `pet.json` / `spritesheet.webp` resources.
`./script/live_app_presentation_smoke.sh` launches the real app process with a
temporary presentation log and verifies that it leaves the offline/connection
state after connecting. When the live app-server exposes readable sessions, the
smoke also requires a `focus` or `conversation` production bubble whose title
matches a sanitized title candidate read from that live session context before it
captures the exact production window and inspects the transparent pet-and-bubble
surface.
`./script/e2e_unavailable_app_server.sh` launches the real app with an
unavailable Codex command and verifies that Mimo stays alive in transparent
production mode with an offline speech bubble.
`./script/e2e_disconnect_app_server.sh` verifies that Mimo first reaches a
connected thread summary state, then survives a stdio app-server exit and shows
the disconnect offline bubble.
`./script/e2e_hanging_daemon_start.sh` verifies that a stuck daemon-start helper
is timed out and does not prevent the app from reaching stdio thread-context
bubbles.
`./script/e2e_proxy_fallback_app_server.sh` verifies that proxy startup failure
falls back to direct stdio without exposing a debug surface or opaque window.
`./script/e2e_state_matrix.sh` captures the exact production window for active,
waiting, multi-thread, review, and failed fake-Codex states, then runs the same
transparent-surface inspection on every capture. The multi-thread capture also
checks the Kataribe Stage: one readable paper report remains close to Mimo while
the named chat charms form a bottom-up stream where new narration enters below
and older charms are only pushed upward.
`./script/e2e_autonomous_energy.sh` launches the production app with a
deterministic fast-drain stamina setup and verifies that Mimo moves, pauses for
rest after stamina drops, shows a non-running rest animation, and keeps the
transparent speech-bubble surface.
Production E2E scripts capture the exact Mimo window and run
`script/inspect_production_capture.swift` to reject blank, fully opaque, or
debug-style surfaces.
`script/inspect_accessibility_surface.swift` also inspects the running app's
macOS accessibility tree. The empty-thread E2E verifies the production surface
identifier, idle narration, and Mimo image node; the six-chat E2E requires
`mimo.kataribe.report` plus `mimo.kataribe.charm.0` through
`mimo.kataribe.charm.5` from the same `MimoDesktopPet.productionSurface` box
that Computer Use sees. The root value names every monitored chat and omits raw
animation or app-server state labels. The same inspector rejects forbidden
debug identifiers, generic `Codex Thread` titles, hidden-count labels, and
private text.

## Controls

Use the `Mimo` menu bar item to:

- show or hide Mimo
- toggle click-through mode
- pause or resume autonomous desktop wandering
- reconnect to Codex
- quit the app

The `Debug Overlay` with the conversation feed is a QA-only surface. Its menu
item is hidden in normal production launches and appears only when
`MIMO_DEBUG_MENU=1` or `MIMO_DEBUG_OVERLAY=1` is set.

When click-through is off, drag Mimo directly to move it. During a drag, the app
uses the `running-right` or `running-left` row based on drag direction.
When not being dragged, production lets Mimo wander by default. Each trip picks
a target `90-240 pt` away while staying within a `360 pt` home radius and the
visible screen. A 60Hz time-based tween with gentle speed waves is frame-limited
to `34 pt/s`, so delayed AppKit updates cannot turn into a sudden jump. The
directional row starts only after the panel has actually moved `8 pt` from the
trip origin; once active, the sprite loops at the fixed `0.36s` per-frame tempo
without restarting on every movement sample. Set
`MIMO_AUTONOMOUS_WINDOW_MOVEMENT=0` to keep the panel anchored.

Autonomous movement has a stamina model: high stamina runs close to the speed
cap, movement gradually drains stamina, and a short stop recovers it quickly.
Once stamina falls below 50%, Mimo's mood can interrupt a trip or choose another rest. Production
also inserts idle, waiting, note-taking, waving, or jumping moments between
trips instead of walking endlessly. While a conversation skit is actively being
read, Mimo keeps walking with the complete Kataribe Stage attached to the panel.
The current narration stays fixed during a walking segment; ordinary chat or
page changes wait until Mimo rests for `0.8s`, while a failure or user action
request may interrupt immediately.

For deterministic QA, set `MIMO_WINDOW_ORIGIN=x,y` to pin the initial panel
origin inside the main visible screen. Set `MIMO_AUTONOMOUS_DISABLED=1` only for
visual inspection runs where timers should not schedule even in-place autonomous
moments. `e2e_autonomous_default_movement.sh` verifies the default-enabled,
speed-limited movement path, while the energy E2E verifies move-then-rest
behavior. Unit tests separately lock the explicit anchored override.

In production mode the panel stays transparent and shows Mimo with the
**Kataribe Stage** selected in
[`design/message-blank-slate-workshop.md`](design/message-blank-slate-workshop.md).
The selected visual reference is
[`mimo-message-blank-slate-12-kataribe-stage.png`](design/ui-proposals/mimo-message-blank-slate-12-kataribe-stage.png).
One matte paper narration surface carries the complete Mimo-style report. A
separate rail of one to six named chat charms provides multi-thread identity
without allocating a second message card to every chat. Every safe chat name is
visible and clickable; the UI never replaces names with a hidden-count summary.
The narrated chat is recreated at the rail bottom, while displaced older charms
move only upward and fade from the top instead of swapping positions.
Each charm fills a compact `29pt` row with only `3pt` of visible separation, so
the rail reads as one continuous conversation feed instead of detached labels.
The selected charm and report share a stable pastel accent, while each other
charm uses a distinct color and unsynchronized breathing below `3pt`. Ambient
charm motion pauses while Mimo walks or the pointer is over it, so interactive
text stays readable.

The report title uses the sanitized Codex chat name. If `name` and `preview` are
missing, the first safe user request from `thread/read(includeTurns: true)` is
used instead of exposing `Codex Thread` or `このチャット`. The body comes from
Codex-backed Mimo speech when available, or from sanitized item activity and a
safe `workSummary` produced by `CodexSessionSummarizer`. It explains a concrete
task and current action or consideration in Mimo's voice, without raw model
output, commands, paths, secrets, `ご主人` UI chrome, or technical status labels.
Long reports paginate at `64` characters; the chat name remains fixed and the
paper shows `page / count` until the next rest-paced page change.

Action-required chats, such as a failure or confirmation request, can interrupt
the narration surface immediately. Other updates remain queued and coalesced,
so frequent app-server notifications do not make the report flicker. Lifecycle
notifications are retained briefly until `thread/list` catches up, keeping a
newly started named chat in the charm rail without turning the companion into a
dashboard or transcript.
The debug overlay is opt-in only: production startup keeps it disabled unless
`MIMO_DEBUG_OVERLAY=1` is set or the menu item is toggled manually.

The production panel is intentionally always on top. Use Hide or Quit from the
menu bar item when Mimo should leave the screen.

See `docs/codex-pets-research.md` for the app-server protocol and mimicry notes.
