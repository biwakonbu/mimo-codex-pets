# Transparency And Edge Pipeline

This document records the transparency workflow used for Mimo and the safer variant to use when a final no-outline cutout is required.

## Problem

Directly keying a generated character from a green chroma background can leave green in antialias pixels. Mimo is especially vulnerable because the character has:

- white hair
- white clothing
- pale blue robot parts
- white wings
- a golden halo with thin lines

These edges can easily mix with green and create a visible fringe on dark, gray, or real Codex UI backgrounds.

## Core Rule

Do not let the actual object edge touch the green key background.

Insert a non-green 3px edge between the object and the chroma key before transparency extraction. That 3px edge can either become the final outline or be removed/replaced after the green has been removed.

## Chroma-Guard Workflow Used For Mimo

Mimo currently keeps a 3px white-blue edge as part of the final style, but that edge is established before chroma-key removal. The generated raw strips are preserved, then a chroma-guard source copy is prepared for spritesheet extraction.

1. Preserve the selected generated row strips under `sources/mimo/generated-raw/`.
2. Create chroma-guard row strips under `sources/mimo/chroma-guard/`:
   - background: exact `#00FF00`
   - guard outline: 3px `#F8FCFF`
   - no alpha channel required at this stage
3. Extract row-stable frames from the chroma-guard strips.
4. Remove the green background.
5. Despill remaining green-ish alpha-positive pixels.
6. Normalize the existing outer boundary color to `#F8FCFF` without expanding alpha.
7. Clamp green-dominant positive-alpha pixels:
   - if `G > max(R, B) + 5`, reduce `G` to `max(R, B) + 5`
8. Normalize fully transparent pixels to `(0,0,0,0)`.
9. Reject the frame if any cell-edge alpha remains.
10. When exporting WebP with Pillow, use lossless output with `exact=True` so transparent RGB stays normalized after decode:
   ```python
   image.save(output, format="WEBP", lossless=True, quality=100, method=6, exact=True)
   ```

This is the version preserved in `pets/mimo/spritesheet.webp`.

## Temporary-Outline Workflow For No-Visible-Outline Cutouts

Use this when the desired final asset should not visibly keep the 3px edge.

1. Generate with a temporary non-green guard outline:
   - background: flat `#00FF00`
   - temporary outline: solid or semi-solid `#F8FCFF`
   - outline thickness: at least `3px`
2. Remove the green background first.
3. Build masks:
   - `subject_mask`: alpha after green removal
   - `expanded_mask`: max-filter/dilated alpha mask
   - `edge_mask`: `expanded_mask - original_object_mask`
4. Remove the temporary outline only after green is gone:
   - subtract `edge_mask` from alpha, or
   - set pixels matching the temporary outline color and outside the original object mask to alpha `0`
5. If the cut edge becomes too jagged, rebuild a neutral antialias edge from the object mask. Do not restore green-contaminated antialias pixels.
6. Normalize fully transparent RGB to `(0,0,0,0)`.
7. Run green and edge gates again.

The important sequence is:

```text
generated raw -> exact chroma-guard copy with 3px non-green edge -> remove green key -> normalize existing edge/RGB -> validate
```

Do not do this sequence:

```text
remove green directly from fragile character edge -> try to hide fringe later
```

That order preserves green contamination in semitransparent pixels.

## Prompt Controls

For regeneration, include controls equivalent to:

```text
Use a clean sticker-sprite edge with a 3px outer outline around the entire character silhouette.
The outline must be light white-blue (#F8FCFF), continuous, and separate all hair, wings, halo, backpack, robot joints, pen, and tablet edges from the chroma-key background.

Do not use green, chroma green, key green, green glow, green rim light, green reflection, green antialiasing, green fringe, green spill, green shadow, green highlight, or green-tinted transparent pixels anywhere inside the character, props, halo, wings, outline, hair, clothes, robot parts, red backpack, pen, or tablet.
The chroma-key color is background only.
```

## Edge Gates

The public QA gates for Mimo are:

- `green_dominant_6_a_gt0 == 0`
- `green_dominant_16_low_alpha == 0`
- `close_key_alpha_gt0 == 0`
- `cell_edge_alpha == 0`
- `transparent_rgb_residue_pixels == 0`

Treat any failure as a blocker.
