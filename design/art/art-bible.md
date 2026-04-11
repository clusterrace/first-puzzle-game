# Art Bible — Sight Lines
> Version 2.0 — authored KAMA-66 (Art Director)
> Supersedes v1.0 (KAMA-44). Key corrections: viewport resolution 760×580 (not
> 1280×720), PAD_Y minimum 40 px (not 50 px), overlay palette entries added.
> Pillars source: `design/gdd/game-pillars.md`

---

## Visual Identity

**Tagline:** *Dark Canvas. Glowing Logic.*

Sight Lines renders on a near-black background. Every interactive element is
defined by controlled light: the observer emits a sight ray; targets glow when
struck; mirrors redirect light. The visual metaphor is optical precision —
lasers, lenses, and sensors arranged in darkness. Nothing decorates; everything
communicates.

This style is a direct expression of Pillar 4 (Show, Don't Tell) and the
MDA Sensation aesthetic: the glow of a lit target and the trace of a ray are
intrinsically satisfying because they are *meaningful* — they tell the player
exactly what the logic is doing.

---

## Testability Band Reference

Every rule below is tagged with one of four bands:

| Band | Label           | Verified by                                 |
|------|-----------------|---------------------------------------------|
| 1    | Numerical       | Code — palette ΔE, WCAG contrast ratios     |
| 2    | Structural      | Code — element sizes, layout positions      |
| 3    | Holistic        | VLM rubric — binary yes/no (advisory only)  |
| 4    | Aspirational    | Human review only — NOT auto-tested         |

Automated pipelines must skip all `[band: 4_aspirational — human-only]` rules.

---

## 1. Color Palette

All colors are authoritative as defined in `palette.json`. The source values
are the float constants declared in `scripts/Game.gd` (C_BG, C_OBS, etc.),
shader uniforms in `shaders/ray_beam.gdshader` and `shaders/target_tile.gdshader`,
`scripts/GridAffordanceRenderer.gd` (affordance overlays), and
`scripts/LevelCompleteOverlay.gd` (overlay UI).

### 1.1 Background and Structural Tiles

| Role       | Hex       | Float (R, G, B)        | Use                              |
|------------|-----------|------------------------|----------------------------------|
| Background | `#14171F` | (0.08, 0.09, 0.12)     | Full-screen base fill            |
| Dark slot  | `#1C212B` | (0.11, 0.13, 0.17)     | Placeable empty slot tiles       |
| Wall       | `#383B45` | (0.22, 0.23, 0.27)     | Impassable wall tiles            |

**Rule 1.1.A** — The background (`#14171F`) must cover 100 % of pixels not
occupied by grid elements, overlays, or UI components.
`[band: 1_numerical — ΔE ≤ 5 vs reference]`

**Rule 1.1.B** — Walls must be visually distinct from both the background and
empty slots. The ΔE between Wall (`#383B45`) and Background (`#14171F`) must
be ≥ 12.
`[band: 1_numerical — ΔE contrast check]`

**Rule 1.1.C** — Dark slots must be visually distinct from Background. ΔE
between Dark slot (`#1C212B`) and Background (`#14171F`) must be ≥ 4.
`[band: 1_numerical — ΔE contrast check]`

**Rule 1.1.D** — The palette maintains a cold, desaturated dark register. No
warm (yellow/orange/red) colors appear in background or structural tiles.
`[band: 4_aspirational — human-only]`

### 1.2 Interactive Pieces

| Role          | Hex       | Float (R, G, B)        | Use                              |
|---------------|-----------|------------------------|----------------------------------|
| Observer      | `#61B3FF` | (0.38, 0.70, 1.00)     | Observer piece fill + icon       |
| Mirror        | `#CCD6F5` | (0.80, 0.84, 0.96)     | Mirror line stroke               |

**Rule 1.2.A** — Observer pieces must render using `#61B3FF` (±ΔE 6). This is
the only saturated cool-blue hue in the piece layer.
`[band: 1_numerical — ΔE ≤ 6 vs reference]`

**Rule 1.2.B** — Mirror pieces must render using `#CCD6F5` (±ΔE 6). Mirrors
are visually lighter than the observer — they are reflective surfaces, not
active emitters.
`[band: 1_numerical — ΔE ≤ 6 vs reference]`

**Rule 1.2.C** — Observer color (`#61B3FF`) must be visually distinct from the
ray beam color (`#6BD6FF`). ΔE between them must be ≥ 5.
`[band: 1_numerical — ΔE contrast check]`

**Rule 1.2.D** — Pieces feel like precision instruments — clean, geometric, no
gradients or textures on the piece body itself. The glow effects belong to the
ray system only.
`[band: 4_aspirational — human-only]`

### 1.3 Ray Beam

| Role          | Hex       | Float (R, G, B, A)          | Use                              |
|---------------|-----------|-----------------------------|----------------------------------|
| Ray beam      | `#6BD6FF` | (0.42, 0.84, 1.00, 0.80)    | Sight ray (additive blend)       |

**Rule 1.3.A** — Ray beams use additive blend mode (`blend_add` in shader). On
the dark background (`#14171F`) the composite result must appear bright cyan,
not white-washed.
`[band: 3_holistic — VLM rubric item R-RAY-01]`

**Rule 1.3.B** — Rays must visually fade (opacity → 0) at the terminal end
before hitting a wall or grid boundary. A hard-cut termination is a visual
defect.
`[band: 3_holistic — VLM rubric item R-RAY-02]`

**Rule 1.3.C** — Ray width: 28 px outer glow diameter as set in `RayRenderer.gd`
(`_BEAM_WIDTH = 28.0`). Automated check: ray bounding box height must be 24–32 px.
`[band: 2_structural — element size check]`

**Rule 1.3.D** — The ray beam has a visible bright core (≈ 12 % of beam width)
surrounded by a softer glow halo. It should read as "light through darkness."
`[band: 4_aspirational — human-only]`

### 1.4 Target Tiles

| Role               | Hex       | Float (R, G, B)        | Use                           |
|--------------------|-----------|------------------------|-------------------------------|
| Target — unlit     | `#7A3333` | (0.48, 0.20, 0.20)     | Standard target, no ray       |
| Target — lit       | `#FF991A` | (1.00, 0.60, 0.10)     | Standard target, ray striking |
| Avoid — unlit      | `#1A8C99` | (0.10, 0.55, 0.60)     | Must-not-light target, safe   |
| Avoid — lit (bad)  | `#F22626` | (0.95, 0.15, 0.15)     | Must-not-light target, struck |

**Rule 1.4.A** — Standard target unlit state: `#7A3333` (±ΔE 8). The reddish-
brown communicates "unfulfilled / needed."
`[band: 1_numerical — ΔE ≤ 8 vs reference]`

**Rule 1.4.B** — Standard target lit state: `#FF991A` (±ΔE 8). The warm amber-
orange communicates "active / achieved."
`[band: 1_numerical — ΔE ≤ 8 vs reference]`

**Rule 1.4.C** — ΔE between Target unlit (`#7A3333`) and Target lit (`#FF991A`)
must be ≥ 30. The state change must be immediately legible.
`[band: 1_numerical — ΔE state contrast check]`

**Rule 1.4.D** — Avoid-target unlit state: `#1A8C99` (±ΔE 8). Teal
communicates "safe / do not disturb."
`[band: 1_numerical — ΔE ≤ 8 vs reference]`

**Rule 1.4.E** — Avoid-target lit (struck) state: `#F22626` (±ΔE 8). Alarm red
communicates "danger / forbidden."
`[band: 1_numerical — ΔE ≤ 8 vs reference]`

**Rule 1.4.F** — Standard targets and avoid-targets must be distinguishable in
their unlit state without relying on color alone. Shape cues (glow ring
presence vs absence) provide supplemental differentiation.
`[band: 3_holistic — VLM rubric item R-TGT-01]`

### 1.5 UI and Feedback Colors

| Role           | Hex       | Float (R, G, B)        | Use                              |
|----------------|-----------|------------------------|----------------------------------|
| UI text        | `#9499B3` | (0.58, 0.60, 0.70)     | Labels, counters, status text    |
| Title text     | `#B3B8D1` | (0.70, 0.72, 0.82)     | Level title, prominent labels    |
| Win state      | `#38FF73` | (0.22, 1.00, 0.45)     | Win condition achieved           |

**Rule 1.5.A** — UI text (`#9499B3`) on background (`#14171F`): WCAG contrast
ratio ≥ 4.5:1 (AA for normal-weight text).
`[band: 1_numerical — WCAG contrast ratio]`

**Rule 1.5.B** — Title text (`#B3B8D1`) on background (`#14171F`): WCAG
contrast ratio ≥ 4.5:1 (AA).
`[band: 1_numerical — WCAG contrast ratio]`

**Rule 1.5.C** — Win state color (`#38FF73`) is reserved exclusively for the
win condition and level-complete overlay. It must not appear during normal
gameplay (pre-win).
`[band: 3_holistic — VLM rubric item R-WIN-01]`

**Rule 1.5.D** — The cool grey palette for UI text (`#9499B3`, `#B3B8D1`) keeps
UI recessive — informational but never competing with gameplay elements.
`[band: 4_aspirational — human-only]`

### 1.6 Overlay and Affordance Colors

These colors appear only in modal overlay contexts (level-complete, pause) or
as interactive affordance feedback. They must not leak into normal gameplay
renders; verification tools should sample these only in overlay-active scenes.

| Role                    | Hex       | Float (R, G, B[, A])       | Use / Source                          |
|-------------------------|-----------|----------------------------|---------------------------------------|
| Scrim                   | `#000000` | (0.00, 0.00, 0.00, 0.72)   | Full-screen darkening overlay         |
| Overlay card bg         | `#1A1F29` | (0.10, 0.12, 0.16, 0.97)   | Pause / level-complete card           |
| Overlay card border     | `#40475C` | (0.25, 0.28, 0.36)         | Card border stroke                    |
| Overlay button bg       | `#1F242E` | (0.12, 0.14, 0.18)         | Button resting state                  |
| Overlay button hover    | `#2B323F` | (0.17, 0.20, 0.25)         | Button hover highlight                |
| Slot dashed border      | `#475266` | (0.28, 0.32, 0.40, 0.80)   | Dashed border on placeable slot       |
| Ghost piece alpha       | N/A       | alpha = 0.40               | Translucent piece preview at hover    |
| Keyboard hint           | `#616680` | (0.38, 0.40, 0.50)         | Undo/Reset/Pause keyboard hint text   |

**Rule 1.6.A** — The level-complete overlay card (`#1A1F29`) must be clearly
distinct from the gameplay background (`#14171F`). ΔE ≥ 6.
`[band: 1_numerical — ΔE contrast check]`

**Rule 1.6.B** — The scrim must reduce perceived background luminance by ≥ 50 %
when the overlay is active. A 72 % opacity black fill achieves this.
`[band: 4_aspirational — human-only]`

**Rule 1.6.C** — Ghost piece previews render at α = 0.40 (±0.05). The preview
must be legible without obscuring the slot tile beneath.
`[band: 1_numerical — alpha channel check ± 0.05]`

---

## 2. Shape Language

**Rule 2.1** — The grid is a regular orthogonal grid. All tiles are square
(80 × 80 px). No hexagonal, triangular, or irregular tiling.
`[band: 2_structural — grid regularity check]`

**Rule 2.2** — Observer pieces: rendered as a filled circle with a hollow
center (inner circle α = BG color at 44 % of outer radius) and a directional
pointer (line + dot). Circle radius ≈ 26 % of cell size (≈ 20.8 px at 80 px
cell). The pointer tip extends to ≈ 160 % of the circle radius from center
(≈ 33 px from center).
`[band: 2_structural — element size check]`

**Rule 2.3** — Mirror pieces: rendered as a diagonal stroke (/ or \) with
16 % cell margin on all sides (≈ 12.8 px inset). Stroke weight = 4 px
(minimum 3 px). The line spans corner to corner of the inset region.
`[band: 2_structural — element size check]`

**Rule 2.4** — Target tiles: rendered as a diamond (L1 / taxicab metric shape)
with L1 radius ≈ 26 % of the cell half-width (≈ 10.4 px from center in pixel
space). A glow ring surrounds the core when lit.
`[band: 2_structural — element size check]`

**Rule 2.5** — All shapes are geometric and anti-aliased. No pixel-art jagged
edges. No raster textures — all rendering is shader/vector-based.
`[band: 3_holistic — VLM rubric item R-SHAPE-01]`

**Rule 2.6** — Shapes are minimal. No decorative outlines, drop shadows, or
embellishments beyond what is functionally required to communicate game state.
`[band: 4_aspirational — human-only]`

---

## 3. Layout and Composition

**Rule 3.1** — The puzzle grid is centered on screen within the 760 × 580 px
viewport. Horizontal padding is computed as `(760 − COLS × 80) / 2`, with a
guaranteed minimum PAD_X of approximately 40 px (for the widest shipped grid).
Vertical padding PAD_Y is computed as `max((580 − ROWS × 80) / 2 − 20, 40)`,
enforcing a hard minimum of **40 px** from viewport top. On all shipped levels
(1–12) the grid must not clip the viewport.
`[band: 2_structural — layout position check]`

**Rule 3.2** — UI elements (level title above grid, piece inventory/hand to
the right of grid, keyboard hints and level counter below grid) must not
overlap the puzzle grid rectangle.
`[band: 2_structural — overlap check]`

**Rule 3.3** — The piece inventory / hand display occupies a clear visual zone
to the right of the grid. It must be readable at a glance (not buried in the
grid area).
`[band: 3_holistic — VLM rubric item R-LAYOUT-01]`

**Rule 3.4** — Visual hierarchy places the grid as the dominant element. The UI
chrome is visually subordinate (smaller, lower contrast). Nothing competes with
the puzzle for the player's attention.
`[band: 4_aspirational — human-only]`

---

## 4. Animation and Feedback States

**Rule 4.1** — Hover valid (carrying piece, hovering valid slot): white overlay
at α = 0.13 on the cell. Color: `rgba(1.0, 1.0, 1.0, 0.13)`.
`[band: 1_numerical — alpha channel check ± 0.05]`

**Rule 4.2** — Hover invalid (carrying piece, hovering occupied/non-slot cell):
red overlay at α = 0.08. Color: `rgba(1.0, 0.30, 0.30, 0.08)`.
`[band: 1_numerical — alpha channel check ± 0.05]`

**Rule 4.3** — Rejection flash peak: `rgba(1.0, 0.15, 0.15, 0.55)`, fading
linearly to transparent over 0.22 s. Must be clearly visible but not alarming.
`[band: 2_structural — animation timing check: duration 0.18–0.26 s]`

**Rule 4.4** — Idle affordance indicator (on interactable pieces): white overlay
at α = 0.28. Color: `rgba(1.0, 1.0, 1.0, 0.28)`. Indicates clickability
without obscuring the piece color.
`[band: 1_numerical — alpha channel check ± 0.05]`

**Rule 4.5** — Win pulse animation on the level-complete overlay: an animated
glow halo around the card oscillates at ≈ 2.4 rad/s (≈ 0.38 Hz) for the outer
glow and ≈ 2.0 rad/s for the border pulse. The animation uses the win state
color (`#38FF73`). The celebration must read as bright and energetic.
`[band: 3_holistic — VLM rubric item R-WIN-02]`

**Rule 4.6** — State transitions (ray recalculation) must update visually within
one rendered frame. No delayed or "lazy" updates to ray paths or target states.
`[band: 4_aspirational — human-only]`

---

## 5. Rendering Constraints

**Rule 5.1** — Target platform is GL Compatibility (OpenGL ES 3.0 / WebGL 2).
No features requiring the Forward+ renderer are permitted.
`[band: 4_aspirational — human-only]`

**Rule 5.2** — Ray shader: ≤ 10 ALU operations per fragment (as designed in
`ray_beam.gdshader`). No texture samples in the ray shader.
`[band: 4_aspirational — human-only]`

**Rule 5.3** — Target shader: ≤ 22 ALU operations per fragment (as designed in
`target_tile.gdshader`). No texture samples in the target shader.
`[band: 4_aspirational — human-only]`

**Rule 5.4** — The game renders on a viewport of **760 × 580 px** (project
setting `window/size/viewport_width=760`, `window/size/viewport_height=580`,
stretch mode `canvas_items`). All art direction measurements in this document
assume this resolution baseline. Do not confuse with any external window size
the stretch mode may produce on the host display.
`[band: 2_structural — resolution baseline]`

---

## 6. Out of Scope

The following are explicitly not part of this art bible:

- **Verification pipeline** — implementation of `scripts/verify_art_direction.py`
  (Technical Artist follow-up task).
- **Golden screenshots** — capture of approved reference renders (QA Tester
  follow-up task).
- **CI integration** — wiring verification into the build pipeline (DevOps
  follow-up task).
- **Character or narrative art** — Sight Lines has no characters or story art.
- **Audio design** — covered by separate sound design documents.
