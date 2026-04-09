# Sight Lines Audio System

## Quick Start

### What's Here

This directory contains the complete sound design specification and implementation system for Sight Lines.

- **SOUND_DESIGN.md** — Complete audio philosophy, SFX specs, mixing parameters, and event catalog
- **PLACEHOLDER_SFX_SPECS.md** — Detailed technical specs for generating or sourcing placeholder audio assets
- **INTEGRATION.md** — Step-by-step guide to wire AudioManager into Game.gd
- **AudioManager.gd** — Centralized audio event system (in `scripts/` directory)

### Files to Create

```
audio/
├── README.md                          (this file)
├── SOUND_DESIGN.md                   (specifications)
├── PLACEHOLDER_SFX_SPECS.md          (generation guide)
├── INTEGRATION.md                    (implementation guide)
└── sfx/                               (create this)
    ├── place_piece.ogg
    ├── mirror_flip_a.ogg
    ├── mirror_flip_b.ogg
    ├── ray_trace.ogg
    ├── target_hit_01.ogg
    ├── target_hit_02.ogg
    ├── target_hit_03.ogg
    ├── target_hit_04.ogg
    ├── win.ogg
    ├── level_next.ogg
    └── hover.ogg
```

### Quick Integration (5 Steps)

1. **Add AudioManager as autoload:**
   - Project → Project Settings → Autoload
   - Add `scripts/AudioManager.gd` as singleton named `AudioManager`

2. **Create audio buses:**
   - Window → Audio panel
   - Add buses: `UI` (init: -8 dB), `Ambient SFX` (init: -14 dB)

3. **Create asset directory:**
   - `mkdir audio/sfx` in project root
   - Populate with .ogg files (see PLACEHOLDER_SFX_SPECS.md)

4. **Integrate into Game.gd:**
   - Follow INTEGRATION.md step-by-step modifications
   - Add 7 AudioManager event calls at key moments

5. **Test:**
   - Run main scene
   - Verify sounds play on piece placement, flip, win, etc.
   - Adjust volumes if needed

---

## Audio Events at a Glance

| Event | Trigger | SFX | When to Add |
|---|---|---|---|
| **Place Piece** | Player places observer/mirror | `sfx_place_piece` | Line ~250 in Game.gd |
| **Mirror Flip** | Player clicks to rotate mirror | `sfx_mirror_flip_a/b` | Line ~255 in Game.gd |
| **Ray Trace** | Ray paths update (optional) | `sfx_ray_trace` | After `_update_rays()` call |
| **Target Hit** | Target illuminated for 1st time | `sfx_target_hit_01-04` | Line ~198 in Game.gd |
| **Win** | All targets lit, win state enter | `sfx_win` | Line ~170 in Game.gd |
| **Level Next** | Player advances to next level | `sfx_level_next` | Line ~229 in Game.gd |
| **Hover** | Hover over valid slot (optional) | `sfx_hover` | Line ~236 in Game.gd |

---

## SFX Specifications (Compact)

### Piece Placement
- **Duration:** 200 ms
- **Tone:** Bright metallic click (400–2400 Hz)
- **Feel:** Punchy, satisfying; validation of placement action
- **Variation:** Slight pitch randomization (±50 cents) at runtime

### Mirror Flip
- **Duration:** 150 ms
- **Tone:** Glass-like toggle (800–3500 Hz)
- **Feel:** Crisp, crystalline; lighter than placement
- **Variation:** Two alternate pitches (A and B) create flip gesture

### Ray Trace (Optional)
- **Duration:** 150 ms
- **Tone:** Ethereal sweep (200–4000 Hz)
- **Feel:** Suggests light motion through space
- **Use:** Add after piece placement/flip if mix feels empty

### Target Hit
- **Duration:** 300 ms each
- **Tone:** Bell chime, harmonic resonance
- **Feel:** Celebration of goal achievement; creates chord when multiple targets light
- **Variation:** Four pitches (200, 250, 300, 350 Hz) = harmonic series

### Win State
- **Duration:** 1000 ms
- **Tone:** Ascending arpeggio or chord progression (300–5000 Hz)
- **Feel:** Grand triumphant moment; extends with reverb tail
- **Mixing:** Master volume -4 dB, other buses duck -3 to -6 dB

### Level Advance
- **Duration:** 500 ms
- **Tone:** Upward pitch bend (200 Hz → 800 Hz)
- **Feel:** Forward-moving bridge between levels
- **Timing:** Plays when player clicks during win screen

### Hover (Optional)
- **Duration:** 100 ms
- **Tone:** Subtle shimmer, air-like (1200–2800 Hz)
- **Feel:** Gentle affordance feedback; can omit if mix is clean
- **Mixing:** Very quiet (-16 dB) to avoid clutter

---

## Audio Bus Architecture

```
Master (0 dB)
├── UI               (-8 dB nominal)
│   └── Contains: place_piece, mirror_flip, hover, target_hit (initial)
│
├── Ambient SFX      (-14 dB nominal)
│   └── Contains: ray_trace
│
└── [Future]
    └── Music (reserved, not used in prototype)
```

### Ducking Rules

**When win state active:**
- Ambient SFX: -14 dB → -20 dB (additional -6 dB)
- UI: -8 dB → -11 dB (additional -3 dB)
- Master: 0 dB (stays same)
- Fade time: 200 ms in, 300 ms out

**Result:** Win sound stands out prominently; other audio quiets.

---

## Voice Budget

- **Max concurrent voices:** 8 (default; adjustable)
- **Kill order if limit hit:** Hover → Ray trace → UI placement → Target hits → Win sounds
- **Typical scenario:** 2–3 voices active
- **Peak (win state):** 4–5 voices

No voice starvation expected in normal gameplay.

---

## Memory Budget

- **Total asset footprint:** ~5 MB (11 files at 32-bit PCM, 44.1 kHz, OGG compressed)
- **Runtime:** All SFX loaded in memory; no streaming needed
- **Safe margin:** Comfortably under budget for puzzle game

---

## Asset Format

- **Codec:** OGG Vorbis (compression-friendly, low-latency)
- **Sample Rate:** 44.1 kHz
- **Bit Depth:** 16-bit
- **Channels:** Mono
- **Naming:** `{sfx_type}_{variant}.ogg` (e.g., `target_hit_01.ogg`)
- **Quality:** OGG quality setting 5–7 (good compression/quality)

---

## Implementation Checklist

- [ ] Read SOUND_DESIGN.md (understand audio philosophy and specs)
- [ ] Read PLACEHOLDER_SFX_SPECS.md (learn how to generate/source audio)
- [ ] Set up AudioManager as autoload in Godot
- [ ] Create audio buses (UI, Ambient SFX)
- [ ] Create `audio/sfx/` directory structure
- [ ] Generate or source 11 placeholder SFX assets
- [ ] Export assets as .ogg files (44.1 kHz, mono, 16-bit)
- [ ] Follow INTEGRATION.md to modify Game.gd (7 event calls)
- [ ] Test in-game and verify sounds trigger correctly
- [ ] Tune volumes and timings based on playtester feedback
- [ ] Commission professional SFX once mechanics validated

---

## Troubleshooting

**No audio playback:**
- Verify sfx_library paths match actual files in `res://audio/sfx/`
- Check buses exist: Audio panel or `_ensure_buses()` in AudioManager

**Sounds too loud/quiet:**
- Adjust volume_db in AudioManager event calls or bus faders
- Typical range: UI -8 dB, Ambient -14 dB, Master 0 dB (hard limit)

**Crackling/pops:**
- Ensure audio assets have proper ADSR envelopes
- No sharp amplitude discontinuities; smooth attack/decay

**Voices cutting off:**
- Increase `max_concurrent_voices` in AudioManager (line 25)
- Default 8 voices should be sufficient; rare edge cases may need 12

**Win sound not playing:**
- Verify `evt_level_complete()` called when win=true
- Check console for errors; ensure bus ducking working

---

## Design Decisions

### Why These Sounds?

1. **Piece placement** — Immediate, satisfying click validates user intent
2. **Mirror flip** — Lighter than placement; refinement action
3. **Ray trace** — Optional; adds "juice" without overload
4. **Target hit** — Harmonic chimes celebrate goal progress
5. **Win state** — Musical gesture (not SFX); grand finale moment
6. **Level advance** — Bridge sound; forward momentum
7. **Hover** — Optional; can be omitted if mix is clean

### Why These Frequencies?

- **UI sounds** (400–3500 Hz): Clear, not harsh; separates from ambience
- **Target hits** (200–350 Hz harmonic series): Creates chord; satisfying resonance
- **Win sound** (300–5000 Hz): Full spectrum; celebratory and rich
- **Hover** (1200–2800 Hz): High, subtle; doesn't interrupt gameplay

### Why Ducking?

**Problem:** Win sound gets lost if other audio plays simultaneously.

**Solution:** Duck other buses when win state enters; refocus mix on celebration.

**Benefit:** Clearer audio hierarchy; win moment feels important and earned.

---

## Future Enhancements

1. **Music:** Add optional background music layer (not in prototype)
2. **Ambience:** If levels expand to 3D, add reverb zones and environmental sounds
3. **Haptics:** Pair audio with haptic feedback for accessibility
4. **Localization:** SFX are language-agnostic; no localization needed
5. **Settings:** Add audio volume slider to main menu (GameManager scope)

---

## References

- Godot Audio Docs: https://docs.godotengine.org/en/stable/tutorials/audio/
- FMOD best practices: Audio event design and bus architecture
- GDC talks: "The Audio of [Game Name]" for design inspiration

---

## Credits

**Audio System Designed By:** Sound Designer (Paperclip Agent 33b302ad)
**Game:** Sight Lines (puzzle-grid-based mechanic prototyping)
**Created:** 2026-04-09

---

## Questions?

See the detailed docs in this directory:
- **"How do I generate the sounds?"** → PLACEHOLDER_SFX_SPECS.md
- **"How do I integrate this into code?"** → INTEGRATION.md
- **"What are the audio specs?"** → SOUND_DESIGN.md
- **"How does the mixing work?"** → SOUND_DESIGN.md § 4–5

