# Mimo Desktop Pet

Mimo Desktop Pet is a small macOS companion app that reuses the public Mimo
Codex pet package from this repository.

The v1 app is read-only:

- it renders `../../pets/mimo/pet.json` and `../../pets/mimo/spritesheet.webp`
- it shows Mimo in a transparent floating desktop panel
- it keeps the panel at macOS screen-saver window level so Mimo stays above
  other apps, across Spaces and fullscreen apps
- it maps Codex app-server thread state to Mimo animation states
- it shows short status and sanitized multi-thread conversation updates in
  speech bubbles
- it does not send prompts, speak audio, inspect the screen, or read Codex
  session JSONL files

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
./script/check_app_bundle_contract.sh
./script/live_app_server_smoke.py
./script/live_app_presentation_smoke.sh
./script/build_and_run.sh --verify
./script/e2e_fake_app_server.sh
./script/e2e_unavailable_app_server.sh
./script/e2e_disconnect_app_server.sh
./script/e2e_state_matrix.sh
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

Codex state sync tries `codex app-server daemon start` as a best-effort helper
with a short timeout, then connects over JSON-RPC through
`codex app-server proxy`. If the daemon helper hangs, proxy startup fails, or
the proxy does not complete the handshake, the companion falls back to direct
`codex app-server --stdio`. If the local Codex app-server cannot be launched,
the companion stays open and shows an offline/waiting status instead of crashing
or waiting forever.
For deterministic manual QA, set `MIMO_CODEX_EXECUTABLE=/path/to/fake-codex`
to point the app and smoke helper at a fake app-server command. The older
`CODEX_BIN` override remains supported for existing scripts, but the Mimo-specific
override takes precedence when both are present.
`./script/live_app_server_smoke.py` performs the same read-only initialize,
loaded-list, thread-list, and thread-read calls against the local app-server.
By default it mirrors production transport selection: bounded daemon start,
proxy first, then direct stdio fallback if proxy cannot initialize. It retries
transient response timeouts with a fresh selected transport so momentary local
Codex stalls do not make the full gate flaky; protocol errors still fail
immediately.
`./script/check_app_server_schema.sh` verifies the generated app-server schema
and cross-checks that every server notification is either handled by the Swift
client or explicitly classified as intentionally ignored. It also keeps the
thread active flags schema-backed.
`./script/check_title_sanitizer_parity.py` verifies that the live smoke helper
and Swift production formatter keep the same ambient title sanitization behavior
for safe, unsafe, instruction-looking, machine-payload, stdout/env-marker,
nested, and fallback thread titles.
`./script/check_app_bundle_contract.sh` builds and verifies the production app
bundle contract: `LSUIElement=true`, the menu-bar companion bundle identity, the
executable bit, and bundled Mimo `pet.json` / `spritesheet.webp` resources.
`./script/live_app_presentation_smoke.sh` launches the real app process with a
temporary presentation log and verifies that it leaves the offline/connection
state after connecting. When the live app-server exposes readable threads, the
smoke also requires a `focus` or `conversation` production bubble whose title
matches a sanitized title candidate read from that live thread context before it
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
checks that the primary Mimo report is the largest, lowest bubble and that the
secondary thread summaries remain smaller, subtly staggered context bubbles
above it without speech tails.
`./script/e2e_autonomous_energy.sh` launches the production app with a
deterministic fast-drain stamina setup and verifies that Mimo moves, pauses for
rest after stamina drops, shows a non-running rest animation, and keeps the
transparent speech-bubble surface.
Production E2E scripts capture the exact Mimo window and run
`script/inspect_production_capture.swift` to reject blank, fully opaque, or
debug-style surfaces.
`script/inspect_accessibility_surface.swift` also inspects the running app's
macOS accessibility tree. The empty-thread E2E verifies the production surface
identifier, idle bubble text, and Mimo image node; the overflow-thread E2E
requires the compact multi-thread bubble stack to expose stable per-bubble
identifiers and the overflow summary from the same
`MimoDesktopPet.productionSurface` box that Computer Use sees. Each production
bubble is grouped into its own accessibility element such as
`MimoDesktopPet.productionSurface.bubble.0.focus`, with the full bubble text in
the label and a primary-first sort priority, so assistive tooling reads Mimo's
main report before secondary context and does not interleave title, marker, and
summary subviews. The same inspector can reject forbidden debug identifiers,
labels, and values; production E2Es use that to ensure the QA-only single
speech bubble and conversation feed are not exposed in normal launches.

## Controls

Use the `Mimo` menu bar item to:

- show or hide Mimo
- toggle click-through mode
- reconnect to Codex
- quit the app

The debug overlay with the conversation feed is a QA-only surface. Its menu item
is hidden in normal production launches and appears only when
`MIMO_DEBUG_MENU=1` or `MIMO_DEBUG_OVERLAY=1` is set.

When click-through is off, drag Mimo directly to move it. During a drag, the app
uses the `running-right` or `running-left` row based on drag direction.
When not being dragged, Mimo periodically wanders to a random visible-screen
position with a 60Hz time-based tween capped at `52 pt/s`. Autonomous movement
has a stamina model: high stamina keeps Mimo near the maximum speed, movement
drains stamina, and resting quickly recovers it to full. Once stamina drops
below 50%, Mimo's mood can interrupt the next hop or stop the current one for a
short break. During breaks Mimo plays idle, waiting, note-taking, waving, or
jumping moments instead of walking endlessly.

For deterministic QA, set `MIMO_WINDOW_ORIGIN=x,y` to pin the initial panel
origin inside the main visible screen. Set `MIMO_AUTONOMOUS_DISABLED=1` only for
visual inspection runs where Mimo must stay still.

In production mode the panel stays transparent and shows only Mimo plus a
stacked list of white speech bubbles. When Codex conversation context is
available, the primary bubble sits closest to Mimo, keeps the speech tail, and
promotes the focused thread into a short Mimo-style report. The visible stack is
capped at five bubbles total: one primary Mimo report plus up to four smaller
secondary context bubbles above it. Those secondary bubbles are compact
thread-status rows with accent markers and no tails, forming a small readable
thread dashboard rather than a transcript panel. Thread bubbles render
`「thread title」summary` as a colored title plus one-line Mimo summary, so
multiple bubbles can be scanned quickly. They do not repeat the longer
`ご主人、...です` phrase, and they do not dump raw model output, commands, or
payload text. Threads can be summarized from sanitized item activity or from
thread/turn status alone. Bubble markers use semantic tone for urgent states
and typed activity kind for ordinary Codex work such as plan, command, file,
browser, image, skill, or mention activity. The stack favors thread coverage, so
each visible thread appears at most once. If more threads are active than the
compact stack can show, Mimo tracks up to six thread contexts and the last
secondary bubble becomes a short overflow note such as `ほか2件も見ています`
instead of silently dropping the extra context. If hidden threads include
attention states, that overflow bubble keeps the strongest hidden tone and uses
short text such as `ほか3件に確認待ち` or `ほか3件に失敗あり`, so urgent work is
not flattened into a neutral counter.
If another visible thread needs attention, such as a failure, confirmation
wait, or review-ready state, that thread is promoted into the primary Mimo
report ahead of a merely active focused thread. The active focused thread stays
visible as a smaller context bubble, so urgent Codex state is not buried in the
stack.
Thread contexts discovered from lifecycle notifications are kept briefly even
when the next `thread/loaded/list` or `thread/list` response has not yet caught
up, so a newly started or updated Codex session does not flicker out of the
production bubble stack just because it is outside the current list window.
The debug overlay is opt-in only: production startup keeps it disabled unless
`MIMO_DEBUG_OVERLAY=1` is set or the menu item is toggled manually.

The production panel is intentionally always on top. Use Hide or Quit from the
menu bar item when Mimo should leave the screen.

See `docs/codex-pets-research.md` for the app-server protocol and mimicry notes.
