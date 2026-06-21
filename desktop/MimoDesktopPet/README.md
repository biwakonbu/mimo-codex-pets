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
production E2E capture gates. Use `./script/qa_all.sh fake-only` only when a
real Codex app-server is intentionally unavailable.

`./script/build_and_run.sh` stages a local app bundle under
`dist/MimoDesktopPet.app`, launches it with `/usr/bin/open -n`, and sets
`MIMO_PET_PACKAGE_DIR` to this repository's `pets/mimo` package unless you
override it.

Codex state sync tries `codex app-server daemon start` as a best-effort helper
with a short timeout, then connects over JSON-RPC through
`codex app-server proxy`. If the daemon helper hangs, proxy startup fails, or
the proxy does not complete the handshake, the companion falls back to direct
`codex app-server --stdio`. If the local Codex app-server cannot be launched,
the companion stays open and shows an offline/waiting status instead of crashing
or waiting forever.
`./script/live_app_server_smoke.py` performs the same read-only initialize,
loaded-list, thread-list, and thread-read calls against the local app-server.
By default it mirrors production transport selection: bounded daemon start,
proxy first, then direct stdio fallback if proxy cannot initialize. It retries
transient response timeouts with a fresh selected transport so momentary local
Codex stalls do not make the full gate flaky; protocol errors still fail
immediately.
`./script/check_app_server_schema.sh` verifies the generated app-server schema
and cross-checks that the Swift notification enum and active flags remain
schema-backed.
`./script/check_title_sanitizer_parity.py` verifies that the live smoke helper
and Swift production formatter keep the same ambient title sanitization behavior
for safe, unsafe, instruction-looking, nested, and fallback thread titles.
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
secondary thread summaries remain smaller context bubbles above it without
speech tails.
Production E2E scripts capture the exact Mimo window and run
`script/inspect_production_capture.swift` to reject blank, fully opaque, or
debug-style surfaces.

## Controls

Use the `Mimo` menu bar item to:

- show or hide Mimo
- toggle click-through mode
- toggle the debug overlay with the conversation feed
- reconnect to Codex
- quit the app

When click-through is off, drag Mimo directly to move it. During a drag, the app
uses the `running-right` or `running-left` row based on drag direction.
When not being dragged, Mimo periodically wanders to a random visible-screen
position with a 60Hz time-based tween capped at `52 pt/s`. Mimo moves in short
hops, rests between them, and plays idle, waiting, note-taking, waving, or
jumping moments instead of walking endlessly.

For deterministic QA, set `MIMO_WINDOW_ORIGIN=x,y` to pin the initial panel
origin inside the main visible screen. Set `MIMO_AUTONOMOUS_DISABLED=1` only for
visual inspection runs where Mimo must stay still.

In production mode the panel stays transparent and shows only Mimo plus a short
fan of white bubbles. When Codex conversation context is available, the primary
bubble sits closest to Mimo, keeps the speech tail, and promotes the focused
thread into a short Mimo-style report. Up to three smaller secondary bubbles sit
above it as compact thread-status chips, with accent markers, no tails, and a
subtle cluster guide behind the bubbles so concurrent threads read as one Mimo
reporting surface rather than a feed panel. Thread bubbles split
`「thread title」summary` text into a tiny title line plus Mimo's short report, so
multiple bubbles can be scanned without relying on a transcript-like list. They
do not repeat the longer `ご主人、...です` phrase, and they do not dump raw model
output, commands, or payload text. Threads can be summarized from sanitized item
activity or from thread/turn status alone. The stack favors thread coverage, so
each visible thread appears at most once. If more threads are active than the
compact stack can show, Mimo tracks up to six thread contexts and the last
secondary bubble becomes a short overflow note such as `ほか3件も見ています`
instead of silently dropping the extra context.
The debug overlay is opt-in only: production startup keeps it disabled unless
`MIMO_DEBUG_OVERLAY=1` is set or the menu item is toggled manually.

The production panel is intentionally always on top. Use Hide or Quit from the
menu bar item when Mimo should leave the screen.

See `docs/codex-pets-research.md` for the app-server protocol and mimicry notes.
