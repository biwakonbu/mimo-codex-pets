# Regeneration Runbook

Use this when repairing or regenerating Mimo.

## Preflight

1. Read `AGENTS.md`.
2. Read:
   - `docs/mimo-production-history.md`
   - `docs/transparency-and-edge-pipeline.md`
   - `docs/generation-controls.md`
3. Preserve Mimo's identity lock.
4. Decide whether the task is:
   - deterministic repair from existing row strips
   - targeted row regeneration
   - full regeneration

Prefer deterministic repair when the source imagery is semantically correct and only extraction, transparency, edge, or motion amplitude is wrong.

## Recommended Repair Order

1. Inspect the current `assets/contact-sheet.png`.
2. Inspect `assets/previews/*.gif`.
3. Read `qa/review.json`, `qa/validation.json`, and `qa/edge-gates.json`.
4. Identify the smallest failing scope.
5. Fix deterministic processing before regenerating imagery.
6. Regenerate only the broken row when source imagery is clipped, unstable, or semantically wrong.

Priority rows for motion repair:

- `idle`
- `waiting`
- `review`
- `jumping`
- `failed`

Only repair `running-right` / `running-left` when cadence or direction is wrong.

For `running-right` / `running-left`, reject broken foot-transfer frames where the sending foot collapses inward, both feet stack unnaturally, or the lower-body centroid jumps mid-loop. Also reject a repair that merely hides bad frames by repeating clean poses: it may pass static QA while no longer reading as running.

The accepted repair path for these rows is:

1. Regenerate `running-right` as an 8-frame side-view chibi gait.
2. Require visible support-foot / sending-foot alternation across the loop.
3. Extract the eight row components through the standard chroma/outline pipeline.
4. Mirror the accepted `running-right` into `running-left` while preserving frame order.

Do not call a repeated hover-step a natural run.

After accepting a regenerated gait, run an explicit size/debris pass on `running-right` and `running-left`:

- connected components per cell must report one main component and zero non-main area
- upper-body width should remain nearly stable across frames; a wide leg pose may change full bbox width, but head/torso scale must not pop
- if the gait is good but body scale pops, normalize the whole sprite with uniform scaling and translation only
- mirror the final cleaned right row into the left row after cleanup, not before
- do not cut the sprite into upper/lower halves or freeze one body part while changing another

Before regenerating a running row, read `docs/running-motion-storyboard.md` and use the frame plan there as the authoritative pose sequence.

## Prompt Requirements For Row Regeneration

Use image generation only for regenerated visual rows. Ground rows with the canonical Mimo reference and, when available, a layout guide.

Required identity text:

```text
Mimo is a tiny non-sexual childlike chibi AI meeting-minutes assistant mascot: silver-white bob hair, big blue eyes, white hooded tech coat with pale blue accents, compact robot joints and ear module at about 30 percent robot feel, tiny white angel wings, small golden halo, red randoseru backpack, holding a pen and tablet/notepad, slightly floating. Keep the design cute, modest, app-pet-safe, and readable at 192x208.
```

Required transparency/edge text:

```text
Create the row on a perfectly flat solid #00FF00 chroma-key background. The background is one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation.
Use a clean sticker-sprite edge with a continuous 3px #F8FCFF outer outline around the entire character silhouette. No character edge may touch or blend into the chroma-key background.
Do not use green, chroma green, green glow, green rim light, green reflection, green antialiasing, green fringe, green spill, green shadow, green highlight, or green-tinted transparent pixels anywhere in the character, props, outline, or effects.
No guide marks, no text, no frame numbers, no UI panels, no detached effects.
```

Row acting:

- `idle`: breathing, blink, tiny halo/wing sway, stable stance
- `waiting`: expectant lean and tablet-presenting gesture, distinct from idle
- `review`: small scan/blink/head tilt loop, quieter than work state
- `jumping`: actual vertical body travel with preserved scale and baseline
- `failed`: expressive slump/recovery without floating symbol effects
- `running`: active task work, not literal running
- `running-right` / `running-left`: directional drag movement with alternating cadence

## Deterministic Extraction Notes

Use row-stable extraction/composition when generated strips have correct motion but output GIFs pop or flatten:

- group connected components per frame
- calculate shared row top/bottom bounds
- compose each frame into a shared viewport
- scale the shared viewport into `192x208`
- do not fit each individual frame to maximum cell height independently

This preserves:

- vertical jump travel
- slump height
- subtle idle/review/waiting motion

## Transparency Steps

For final-outline Mimo:

1. Remove chroma background.
2. Despill green-ish pixels.
3. Compose row-stable cells.
4. Add translucent 3px `#F8FCFF` outline.
5. Clamp green dominance.
6. Normalize transparent RGB.
7. Validate.

When exporting the final WebP with Pillow, use lossless output and `exact=True` so fully transparent pixels continue to decode as `(0,0,0,0)`:

```python
image.save(output, format="WEBP", lossless=True, quality=100, method=6, exact=True)
```

For no-outline transparent variants:

1. Generate/use a temporary 3px non-green outline.
2. Remove chroma green first.
3. Remove the temporary outline mask.
4. Rebuild a neutral non-green antialias edge if needed.
5. Normalize transparent RGB.
6. Validate.

See `docs/transparency-and-edge-pipeline.md` for details.

## Packaging

The final public package is:

```text
pets/mimo/pet.json
pets/mimo/spritesheet.webp
```

To install locally:

```bash
mkdir -p ~/.codex/pets/mimo
cp pets/mimo/pet.json pets/mimo/spritesheet.webp ~/.codex/pets/mimo/
```

## Required Public Artifacts

Update these before commit:

```text
assets/contact-sheet.png
assets/previews/*.gif
assets/demo-videos/mimo-state-grid.mp4
assets/demo-videos/mimo-background-sweep.mp4
assets/demo-videos/mimo-state-spotlight.mp4
qa/validation.json
qa/review.json
qa/edge-gates.json
qa/qa-summary.json
```

Do not commit live screen recordings.

## Acceptance Gates

Block commit if any of these fail:

```text
validation errors == 0
validation warnings == 0
review errors == 0
review warnings == 0
transparent_rgb_residue_pixels == 0
green_dominant_6_a_gt0 == 0
green_dominant_16_low_alpha == 0
close_key_alpha_gt0 == 0
cell_edge_alpha == 0
```

Also visually inspect contact sheet and GIF/video previews. Reject:

- clipped halo or wings
- green fringe
- dirty or jagged edges
- size popping caused by extraction
- wrong row semantics
- overly stiff motion
- identity drift
- detached effects or guide artifacts

## Commit Checklist

1. Confirm no public-risk recordings:
   ```bash
   find . -type f | sort
   rg -n 'codex-live|/Users/|current-screen|screen recording|video-review-contact|\\.mov' .
   ```
2. Run `git diff --check`.
3. Commit with a concise message.
4. Push `main`.
