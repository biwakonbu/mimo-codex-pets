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
swift test
./script/check_app_server_schema.sh
./script/live_app_server_smoke.py
./script/live_app_presentation_smoke.sh
./script/build_and_run.sh --verify
./script/e2e_fake_app_server.sh
```

The script stages a local app bundle under `dist/MimoDesktopPet.app`, launches it
with `/usr/bin/open -n`, and sets `MIMO_PET_PACKAGE_DIR` to this repository's
`pets/mimo` package unless you override it.

Codex state sync tries `codex app-server daemon start` as a best-effort helper,
then uses the JSON-RPC stdio transport via `codex app-server --stdio`. If the
local Codex app-server cannot be launched, the companion stays open and shows an
offline/waiting status instead of crashing.
`./script/live_app_server_smoke.py` performs the same read-only initialize,
loaded-list, thread-list, and thread-read calls against the local app-server.
`./script/live_app_presentation_smoke.sh` launches the real app process with a
temporary presentation log and verifies that it leaves the offline/connection
state after connecting.

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

In production mode the panel stays transparent and shows only Mimo plus a short
stack of white bubbles. The primary bubble carries the current Codex status, and
up to two secondary bubbles summarize recent visible Codex threads without
dumping raw model output, commands, or payload text.

The production panel is intentionally always on top. Use Hide or Quit from the
menu bar item when Mimo should leave the screen.

See `docs/codex-pets-research.md` for the app-server protocol and mimicry notes.
