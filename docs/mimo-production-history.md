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
