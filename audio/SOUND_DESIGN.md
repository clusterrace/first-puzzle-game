# Sight Lines — Sound Design Document

## 1. Audio Philosophy

**Sonic Goal:** Provide clear feedback for every player action without cluttering the minimal visual aesthetic. Each sound communicates information about game state and validates player intent.

**Mix Priority:** UI feedback > Target hit moments > Piece placement > Ray traces > Ambience

---

## 2. SFX Specification Sheets

### 2.1 Piece Placement

**Identifier:** `sfx_place_piece`

**Purpose:** Confirm successful placement of observer or mirror; provides tactile satisfaction.

**Characteristics:**
- Frequency range: 400–2400 Hz (mid-range, punchy)
- Duration: 180–220 ms
- Envelope: Fast attack (20–40 ms), sustain, medium decay (80–120 ms)
- Tone: Bright, metallic click with resonant body

**Behavior:**
- Trigger: When player places observer or mirror into an empty slot
- Volume: -8 dB (bus: UI)
- Variation: Slight pitch randomization (±50 cents) per placement to avoid repetition
- Fallback: Play at reduced volume if voice-count limit hit

**Notes:** This is the foundational feedback sound. It should feel deliberate and satisfying without being harsh.

---

### 2.2 Mirror Flip

**Identifier:** `sfx_mirror_flip`

**Purpose:** Confirm observer or mirror rotation; lighter than placement.

**Characteristics:**
- Frequency range: 800–3500 Hz (higher, more crystalline)
- Duration: 140–180 ms
- Envelope: Very fast attack (15 ms), minimal sustain, short decay (60 ms)
- Tone: Clear, glass-like toggle sound with minimal body resonance

**Behavior:**
- Trigger: When player clicks an already-placed mirror to flip it (/ ↔ \)
- Volume: -11 dB (bus: UI)
- Variation: Alternate between two slightly different pitches (±100 cents apart) to create a flip gesture
- Concurrency: Allow multiple rapid flips without voice-count pressure

**Notes:** Lighter than placement because it's a refinement action, not a commitment. Pitch variation creates a "flip" sensation.

---

### 2.3 Ray Trace / Reflection

**Identifier:** `sfx_ray_trace`

**Purpose:** Sonify the path of the sight ray as it updates; creates a sense of light moving through space.

**Characteristics:**
- Frequency range: 200–4000 Hz (broad, "whoosh" quality)
- Duration: 120–180 ms per segment (scales with ray length)
- Envelope: Smooth attack (30 ms), taper, soft decay (100 ms)
- Tone: Ethereal, sweeping tone that suggests motion

**Behavior:**
- Trigger: When `_update_rays()` recalculates ray paths (after piece placement or flip)
- Volume: -14 dB (bus: Ambient SFX)
- Layering: 1–2 harmonically related frequencies sweep upward as ray travels
- Falloff: Each reflection point adds a subtle harmonic accent
- Concurrency: Limit to 1 instance per update cycle (no stacking)

**Notes:** This sound is optional and subtle—it adds "juice" without overloading the mix. Can be disabled in settings if too distracting.

---

### 2.4 Target Hit / Illuminate

**Identifier:** `sfx_target_hit`

**Purpose:** Celebrate moment when a target is successfully illuminated; provides goal-oriented feedback.

**Characteristics:**
- Frequency range: 800–2500 Hz (warm, resolved quality)
- Duration: 250–320 ms
- Envelope: Attack (30 ms), sustain (80 ms), longer decay (100–150 ms)
- Tone: Chiming, bell-like resonance with harmonic richness

**Behavior:**
- Trigger: When a target cell transitions from dark → lit (first illumination only, not per-update)
- Volume: -5 dB (bus: Master, slight ducking applied)
- Variation: Each target uses a different pitch (harmonic series: 200 Hz base, then 250, 300, 350 Hz for targets beyond first)
- Concurrency: Play all simultaneous target hits; stagger slightly (12–25 ms) if 3+ targets light together

**Notes:** This is a celebration moment. It should feel rewarding but not bombastic. Multiple targets lighting should create a chord, not chaos.

---

### 2.5 Win State / Level Complete

**Identifier:** `sfx_win`

**Purpose:** Grand finale moment; confirms level completion and readiness to advance.

**Characteristics:**
- Frequency range: 300–5000 Hz (full spectrum flourish)
- Duration: 800–1200 ms (extended, musical)
- Envelope: Attack (50 ms), rise (200 ms), sustain (300 ms), decay (200–400 ms)
- Tone: Ascending arpeggio or chord progression suggesting triumph

**Behavior:**
- Trigger: When `win = true` and the draw cycle renders the win overlay
- Volume: -4 dB (bus: Master, all other buses duck -3 dB)
- Composition: 3–4 tonal layers: bass (resolves to tonic), mid (major third or fifth), bright accent (octave or harmonic)
- Falloff: Can play only once per level win (flag to prevent repeat-fire if overlay stays visible)

**Notes:** This sound should feel musical and celebratory. It's the payoff for solving the puzzle. Reference: think "solved puzzle" from Portal or Baba Is You.

---

### 2.6 UI Interaction (Hover / Selection)

**Identifier:** `sfx_hover`

**Purpose:** Optional feedback when mouse hovers over valid placement slots; signals affordance.

**Characteristics:**
- Frequency range: 1200–2800 Hz (bright, non-intrusive)
- Duration: 80–120 ms
- Envelope: Fast attack (10 ms), immediate decay (70–100 ms)
- Tone: Minimal, air-like "shimmer" without melodic content

**Behavior:**
- Trigger: When `hover_cell` changes and targets a valid SLOT with pieces in hand
- Volume: -16 dB (bus: UI, very subtle)
- Variation: Optional (can omit if mix feels clean without it)
- Concurrency: Limit to 1 instance; cancel previous hover sound when cell changes

**Notes:** This is optional and subtle. If not implemented, no loss of clarity. Only add if it enhances rather than clutters.

---

### 2.7 Level Transition / Advance

**Identifier:** `sfx_level_next`

**Purpose:** Bridge moment between levels; suggests progress and anticipation for next puzzle.

**Characteristics:**
- Frequency range: 200–3000 Hz (rising arc)
- Duration: 400–600 ms
- Envelope: Attack (40 ms), rise (200 ms), short sustain, decay (100 ms)
- Tone: Uplifting ascending tone or pitch bend

**Behavior:**
- Trigger: When player clicks during win screen and next level loads
- Volume: -6 dB (bus: Master)
- Timing: Play when `load_level()` executes
- Crossfade: Win sound fades at -2 dB/100ms as level-next sound enters

**Notes:** This can be a simple pitch bend or a short melodic gesture. It should feel forward-moving without being abrupt.

---

## 3. Audio Event Catalog

| Event ID | Trigger Condition | SFX Spec | Volume | Bus | Concurrency | Priority |
|---|---|---|---|---|---|---|
| `EVT_PLACE_PIECE` | `grid[r][c] = piece` after hand placement | sfx_place_piece | -8 dB | UI | 1 voice | High |
| `EVT_FLIP_MIRROR` | Player clicks placed mirror to toggle | sfx_mirror_flip | -11 dB | UI | Unlimited | High |
| `EVT_UPDATE_RAYS` | `_update_rays()` completes | sfx_ray_trace | -14 dB | Ambient SFX | 1 voice | Medium |
| `EVT_TARGET_LIT` | Target transitions dark → lit | sfx_target_hit | -5 dB | Master | Multiple (staggered) | High |
| `EVT_WIN` | `win = true`, overlay renders | sfx_win | -4 dB | Master | 1 voice | High |
| `EVT_LEVEL_NEXT` | Player clicks during win screen | sfx_level_next | -6 dB | Master | 1 voice | High |
| `EVT_HOVER` | `hover_cell` changes to valid SLOT | sfx_hover | -16 dB | UI | 1 voice | Low |

---

## 4. Audio Bus Architecture

```
Master (0 dB)
├── UI (-8 dB nominal, ducks to -11 dB during win)
├── Ambient SFX (-14 dB nominal, ducks to -20 dB during win)
└── Music (N/A for prototype; reserved for future)
```

**Ducking Rules:**
- When `EVT_WIN` fires: Ambient SFX ducks -6 dB additional, UI ducks -3 dB additional
- During active gameplay: no ducking
- Ducking fade time: 200 ms in, 300 ms out

---

## 5. Mixing Parameters

### 5.1 Volume Targets

| Bus | Nominal | Min | Max | Notes |
|---|---|---|---|---|
| Master | 0 dB | -∞ | 0 dB | Hard limiter at 0 dB |
| UI | -8 dB | -14 dB | -5 dB | Ranges for different UI event types |
| Ambient SFX | -14 dB | -20 dB | -8 dB | Scales with ray complexity |

### 5.2 Distance Attenuation

Not applicable in current prototype (no 3D positional audio). All sounds are screen-space (2D falloff if future levels expand).

### 5.3 Prioritization

If voice limit is hit (≤ 8 voices simultaneously):
1. **Kill order:** Hover SFX → Ray trace → Ambient → UI placement → Target hits → Win sounds
2. **Alternative:** Queue placement sounds to play immediately after voice frees up
3. **Never cut:** Win state sounds or target hit sounds during puzzle-solving

---

## 6. Placeholder Asset List

| Asset ID | Spec | File (TBD) | Duration | Notes |
|---|---|---|---|---|
| `sfx_place_piece_01` | sfx_place_piece | `res://audio/sfx/place_piece.ogg` | 200 ms | Bright metallic click |
| `sfx_mirror_flip_01` | sfx_mirror_flip | `res://audio/sfx/mirror_flip_a.ogg` | 150 ms | Glass toggle A |
| `sfx_mirror_flip_02` | sfx_mirror_flip | `res://audio/sfx/mirror_flip_b.ogg` | 150 ms | Glass toggle B (pitch variant) |
| `sfx_ray_trace_01` | sfx_ray_trace | `res://audio/sfx/ray_trace.ogg` | 150 ms | Ethereal sweep |
| `sfx_target_hit_01` | sfx_target_hit | `res://audio/sfx/target_hit_01.ogg` | 300 ms | Bell chime (pitch 1) |
| `sfx_target_hit_02` | sfx_target_hit | `res://audio/sfx/target_hit_02.ogg` | 300 ms | Bell chime (pitch 2) |
| `sfx_target_hit_03` | sfx_target_hit | `res://audio/sfx/target_hit_03.ogg` | 300 ms | Bell chime (pitch 3) |
| `sfx_target_hit_04` | sfx_target_hit | `res://audio/sfx/target_hit_04.ogg` | 300 ms | Bell chime (pitch 4) |
| `sfx_win` | sfx_win | `res://audio/sfx/win.ogg` | 1000 ms | Triumphant ascent |
| `sfx_level_next` | sfx_level_next | `res://audio/sfx/level_next.ogg` | 500 ms | Forward-moving rise |
| `sfx_hover` | sfx_hover | `res://audio/sfx/hover.ogg` | 100 ms | Subtle shimmer (optional) |

---

## 7. Audio Feedback Map

### Player Actions → Sonic Feedback

| Action | Primary Sound | Secondary Sounds | Timing |
|---|---|---|---|
| Place observer in empty slot | sfx_place_piece | sfx_ray_trace (after update) | Immediate → +50 ms |
| Place mirror in empty slot | sfx_place_piece | sfx_ray_trace (after update) | Immediate → +50 ms |
| Flip placed mirror | sfx_mirror_flip | sfx_ray_trace (if ray path changes) | Immediate → +50 ms |
| Mouse hover over valid slot | sfx_hover (optional) | None | Debounce 150 ms |
| All targets illuminate | sfx_target_hit (×N, staggered) | None | As targets light |
| Level complete (win state) | sfx_win | (Ambient SFX ducks) | Immediate |
| Advance to next level | sfx_level_next | (Win sound fades) | Immediate after click |

---

## 8. Implementation Notes

### 8.1 Godot Integration Points

- **Placement trigger:** `Game.gd` line 250, after `grid[r][c] = piece`
- **Mirror flip trigger:** `Game.gd` line 255–258, after mirror state changes
- **Ray update trigger:** `Game.gd` line 153 `_update_rays()`, fire ray trace sound once per update
- **Target hit trigger:** `Game.gd` line 196–198, fire target hit sound when `lit[Vector2i(nr, nc)] = true`
- **Win trigger:** `Game.gd` line 170, after `win = true` check
- **Level next trigger:** `Game.gd` line 229, after `load_level(next)`

### 8.2 Voice Budget

- **Max simultaneous voices:** 8
- **Typical scenario:** 1–2 voices at rest
- **Peak scenario (win):** 3–4 voices (win + target hits + ducks)

### 8.3 Memory Constraints

- **Estimated footprint:** ~5 MB (11 assets at 32-bit PCM, 44.1 kHz)
- **Streaming:** Not needed for prototype; all SFX fit in memory

---

## 9. Mix Hierarchy

**By Importance (highest to lowest):**
1. Win state sounds (celebration, high priority)
2. Target hits (goal feedback, core gameplay)
3. UI placement sounds (player action confirmation)
4. Mirror flip (refinement feedback)
5. Ray traces (optional juicing)
6. Hover feedback (optional affordance)

---

## 10. Future Considerations

- **Ambience layers:** If levels grow, consider background tones (silence is fine for now)
- **Music:** None planned for prototype; add in post-launch polish
- **Accessibility:** All feedback is sonically distinct; consider adding haptic feedback as alternative
- **Tuning:** Volumes and timings are recommendations; fine-tune based on playtester feedback

