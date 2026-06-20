# Mimo Desktop Pet

Mimo Desktop Pet is a small macOS companion app that reuses the public Mimo
Codex pet package from this repository.

The v1 app is read-only:

- it renders `../../pets/mimo/pet.json` and `../../pets/mimo/spritesheet.webp`
- it shows Mimo in a transparent floating desktop panel
- it maps Codex app-server thread state to Mimo animation states
- it shows short status and sanitized conversation updates in a speech bubble
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
./script/build_and_run.sh --verify
./script/e2e_fake_app_server.sh
```

The script stages a local app bundle under `dist/MimoDesktopPet.app`, launches it
with `/usr/bin/open -n`, and sets `MIMO_PET_PACKAGE_DIR` to this repository's
`pets/mimo` package unless you override it.

Codex state sync uses `codex app-server daemon start` and the JSON-RPC stdio
transport via `codex app-server --stdio`. If the local Codex CLI does not have a
managed standalone app-server install available, the companion stays open and
shows an offline/waiting status instead of crashing.

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
position, rests, and plays idle or note-taking moments.

See `docs/codex-pets-research.md` for the app-server protocol and mimicry notes.
