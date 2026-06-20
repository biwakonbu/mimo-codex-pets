# Mimo Pet Generation Controls

Use these controls for any future Mimo row regeneration.

## Positive Edge Control

- Use a clean sticker-sprite edge with a translucent 3px outer outline around the entire character silhouette.
- The outer outline should be light white-blue, approximately `#F8FCFF` at about 65% opacity, continuous, and thick enough to separate the character from the chroma-key background without looking like a hard sticker border.
- Keep all character pixels fully separated from the background by the outline; no hair, wing, halo, backpack, robot joint, pen, or tablet edge may touch or blend into the chroma key.

## Negative Prompt Control

Do not use green, chroma green, key green, green glow, green rim light, green reflection, green antialiasing, green fringe, green spill, green shadow, green highlight, or green-tinted transparent pixels anywhere inside the character, props, halo, wings, outline, hair, clothes, robot parts, red randoseru, pen, or tablet.

No chroma-key color may appear in any object pixel, edge pixel, outline pixel, highlight, shadow, semitransparent antialias pixel, glow, material reflection, or motion frame. The chroma-key color is background only.

Avoid thin fragile edges. Avoid semi-transparent edge pixels that mix object color with the background. Avoid jagged cutout edges, soft green halos, color contamination, and background-colored outlines.

## Row Acting Controls

- `idle`: calm breathing, blink, tiny halo and wing sway, stable floating stance. No waving, walking, working, reviewing, or new props.
- `waiting`: expectant lean and tablet-presenting pose, clearly asking for user input. Keep it distinct from idle.
- `review`: quiet scan, blink, and small head tilt while holding the existing tablet/notes. Quieter than active work.
- `jumping`: real vertical body travel with preserved scale and baseline; no shadow, dust, landing marks, or detached effects.
- `failed`: expressive slump and recovery using body pose only; no floating symbols, red X marks, detached smoke, or loose tears.
- `running`: active task work or processing, not literal foot-running.
- `running-right` / `running-left`: directional drag movement with alternating cadence, using only body and prop movement.

## Postprocess Controls

- Extract frames with row-stable scale and position; do not resize every frame independently to the same full-cell height.
- Preserve natural vertical amplitude for `jumping` and `failed` while keeping every frame inside `192x208`.
- Clamp or remove any alpha-positive pixel where green is dominant over both red and blue channels.
- Normalize fully transparent pixels to `(0,0,0,0)`.
- Reject any cell-edge alpha after the 3px outline is applied.

## QA Gate

Reject the output if any used frame has:

- visible green fringe on black, gray, white, or checkerboard preview backgrounds
- any alpha-positive pixel close to the chroma-key color
- green-dominant edge pixels
- transparent pixels with non-zero RGB residue
- a silhouette that reaches the cell edge after the 3px outline
