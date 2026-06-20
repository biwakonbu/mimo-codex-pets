# Running Motion Storyboard

This document defines the intended `running-right` / `running-left` motion before sprite generation. It exists to avoid repairing animation by hiding broken frames or compositing unrelated body halves.

## Directional State Intent

`running-right` and `running-left` are Codex drag-movement states. They should read as a cute, small chibi run or hurry-trot, not a literal sprint and not a hover-step.

The whole character must be animated as one coherent full-body sprite in every frame. Do not cut the sprite into upper/lower halves or freeze the torso while only changing the legs.

## Frame Plan

The accepted row is an 8-frame loop. `running-left` is the mirrored version of `running-right` after `running-right` is accepted.

| Frame | Phase | Body | Legs | Arms / Props | Secondary Motion |
| --- | --- | --- | --- | --- | --- |
| 0 | Right-foot contact | torso slightly forward, normal height | right foot forward/down, left foot back | tablet and pen held close | hair and halo trail slightly back |
| 1 | Down / weight | body 2 px lower, squash is subtle | feet pass under body, knees bent but separated | tablet steady, elbows compress slightly | backpack dips |
| 2 | Left-foot swing | body rises toward neutral | left leg swings forward, right leg pushes back | hands remain readable | coat hem opens slightly |
| 3 | Up / light airborne | body 2 px higher | both feet separated from each other, no stacking | tablet steady, no arm pumping | wings lift slightly |
| 4 | Left-foot contact | torso still forward, normal height | left foot forward/down, right foot back | props stable | hair catches up |
| 5 | Down / weight | body 2 px lower | feet pass under body, knees separated | elbows compress slightly | backpack dips |
| 6 | Right-foot swing | body rises toward neutral | right leg swings forward, left leg pushes back | props stable | coat hem opens slightly |
| 7 | Up / light airborne | body 2 px higher | feet separated, no crossed shoes | tablet and pen still visible | wings and halo lift slightly |

## Acceptance Rules

- Every frame is a full-body sprite frame.
- No frame may be made by stitching unrelated upper and lower body parts.
- Full-body scale may be normalized during extraction, but body parts must not be independently scaled or cut.
- The head, torso, halo, wings, backpack, pen, and tablet must remain the same design and scale across frames.
- Full bbox width can change because of leg extension; upper-body width should not pop.
- Feet must alternate clearly: contact, down, passing/swing, up, opposite contact.
- No crossed feet, stacked knees, collapsed sending foot, or tangled shoes.
- No speed lines, dust, floor shadows, detached sparkles, guide marks, text, or UI panels.
- Directional rows must have zero disconnected alpha debris after extraction.

## Cleanup Limits

Allowed deterministic cleanup:

- chroma-key removal and despill
- connected-component debris removal
- whole-sprite translation
- whole-sprite uniform scaling for row-level size normalization
- row-level baseline alignment
- final 3 px outline and transparent RGB normalization

Forbidden cleanup:

- cutting the sprite into upper/lower halves
- freezing one body part while replacing another from a different frame
- drawing or patching new limbs locally
- hiding bad gait by repeating only clean frames
