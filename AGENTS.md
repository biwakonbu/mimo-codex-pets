# AGENTS.md

This repository publishes and preserves the Mimo custom Codex pet package.

## Working Language

- User-facing responses for this project should be Japanese.
- Repository docs may be English when they are meant to be public and reusable.

## Scope

Keep the repository public-safe:

- Commit pet package files, QA data, generated previews, and sprite-derived demo videos.
- Do not commit live Codex screen recordings, desktop captures, local browser screenshots, raw generated-image rollout folders, or files that reveal local workspace context.
- Do not commit `.DS_Store`, temporary frame directories, or local rebuild scratch files.

## Mimo Identity Lock

Every regeneration must preserve Mimo's identity:

- tiny non-sexual childlike chibi meeting-minutes AI assistant
- white/silver bob hair, big blue eyes, soft anime sticker style
- small golden halo, small white angel wings, gentle floating pose
- white tech coat with pale blue accents
- red randoseru backpack
- light robot accents, about 30% robot feel
- pen and tablet/notepad props

Do not add readable text, logos, UI panels, speech bubbles, detached sparkles, shadows, speed lines, dust, scenery, or new unrelated props.

## Codex Pet Contract

The final atlas must remain:

- `1536x1872`
- 8 columns x 9 rows
- `192x208` per cell
- row order: `idle`, `running-right`, `running-left`, `waving`, `jumping`, `failed`, `waiting`, `running`, `review`
- unused cells fully transparent

Package files must stay together:

- `pets/mimo/pet.json`
- `pets/mimo/spritesheet.webp`

## Transparency And Edge Policy

Green contamination is a blocker. For every regeneration or repair:

- Use a removable flat chroma-key background only as background.
- Keep green out of all object pixels, antialias pixels, highlights, shadows, halo, wings, hair, coat, robot parts, red backpack, pen, tablet, and outline.
- Use a temporary or final 3px light white-blue outer edge (`#F8FCFF`) to keep the sprite separated from the key background.
- After key removal, normalize fully transparent pixels to `(0,0,0,0)`.
- Reject any positive-alpha pixel close to key green.
- Reject green-dominant edge pixels.
- Reject any alpha on the outer cell edge.

When a no-visible-outline transparent cutout is needed, use the temporary-outline workflow documented in `docs/transparency-and-edge-pipeline.md`: create the 3px non-green edge before keying, remove the green background, then remove or replace the temporary edge deliberately. Do not key directly against hair, wings, halo, or white clothing.

## Motion Policy

Prefer row-stable extraction and composition over per-frame fit-to-cell scaling.

- Do not resize every frame independently to the same full-cell height.
- Preserve vertical travel for `jumping`.
- Preserve slump/recovery height for `failed`.
- Keep `idle` alive but calm.
- Keep `waiting` visually distinct from `idle`.
- Keep `running` as active task work, not literal running.
- Mirror `running-left` from `running-right` only when identity, timing, prop placement, and direction semantics remain correct.

## Required QA Before Commit

Before committing regenerated assets, update and inspect:

- `assets/contact-sheet.png`
- `assets/previews/*.gif`
- `qa/validation.json`
- `qa/review.json`
- `qa/edge-gates.json`
- `qa/qa-summary.json`

Required gates:

- validation errors: `0`
- review errors: `0`
- review warnings: `0`
- `transparent_rgb_residue_pixels == 0`
- `green_dominant_6_a_gt0 == 0`
- `green_dominant_16_low_alpha == 0`
- `close_key_alpha_gt0 == 0`
- `cell_edge_alpha == 0`

Visually review previews as well as JSON. JSON passing is necessary, not sufficient.

## Documentation

When changing generation, extraction, transparency, or motion behavior:

- update `docs/mimo-production-history.md`
- update `docs/transparency-and-edge-pipeline.md` if edge/keying logic changed
- update `docs/regeneration-runbook.md` if commands or acceptance gates changed
- keep public docs free of local absolute paths and private screen contents
