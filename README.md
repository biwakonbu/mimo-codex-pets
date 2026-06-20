# Mimo Codex Pet

Mimo is a custom Codex pet: a tiny angelic robot meeting-minutes AI assistant with white bob hair, blue eyes, a halo, small wings, a red randoseru, light robot accents, a pen, and a tablet.

The final pet atlas was rebuilt with row-stable scale and position so jumping and failed/slump motion keep real vertical movement instead of being normalized to the same full-cell height.

## Install

Copy the package into your Codex pets directory:

```bash
mkdir -p ~/.codex/pets/mimo
cp pets/mimo/pet.json pets/mimo/spritesheet.webp ~/.codex/pets/mimo/
```

Then select or reload the custom pet in Codex.

## Package

- `pets/mimo/pet.json`
- `pets/mimo/spritesheet.webp`

Atlas contract:

- Size: `1536x1872`
- Cell: `192x208`
- Grid: `8x9`
- States: `idle`, `running-right`, `running-left`, `waving`, `jumping`, `failed`, `waiting`, `running`, `review`

## QA Artifacts

- `assets/contact-sheet.png`
- `assets/previews/*.gif`
- `assets/demo-videos/mimo-state-grid.mp4`
- `assets/demo-videos/mimo-background-sweep.mp4`
- `assets/demo-videos/mimo-state-spotlight.mp4`
- `qa/validation.json`
- `qa/review.json`
- `qa/edge-gates.json`
- `qa/qa-summary.json`

Live Codex screen recordings are intentionally excluded from this public repository because they include local desktop and workspace context.

## Regeneration Docs

- `AGENTS.md` — repository rules for future agents
- `docs/mimo-production-history.md` — session-derived brief, decisions, repairs, and QA history
- `docs/transparency-and-edge-pipeline.md` — chroma-key, 3px edge, edge-removal, and validation workflow
- `docs/regeneration-runbook.md` — practical repair/regeneration checklist
- `docs/generation-controls.md` — prompt controls for future Mimo row generation

## Validation Summary

- `review.json`: errors `0`, warnings `0`
- `validation.json`: errors `0`, warnings `0`
- `transparent_rgb_residue_pixels`: `0`
- `green_dominant_6_a_gt0`: `0`
- `green_dominant_16_low_alpha`: `0`
- `close_key_alpha_gt0`: `0`
- `cell_edge_alpha`: `0`
