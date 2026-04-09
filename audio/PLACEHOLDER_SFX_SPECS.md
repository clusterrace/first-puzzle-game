# Placeholder SFX Specifications

## Overview

This document provides detailed technical specifications for generating or sourcing placeholder sound effects for Sight Lines. Each spec includes synthesis parameters, frequency characteristics, envelope details, and generation methods.

**Target Specifications:**
- Format: OGG Vorbis (compression-friendly, low latency)
- Sample Rate: 44.1 kHz
- Bit Depth: 16-bit
- Channels: Mono (stereo optional for future polish)
- Directory: `res://audio/sfx/`

---

## 1. place_piece.ogg

**Purpose:** Bright, punchy click confirming piece placement.

**Characteristics:**
- Duration: 200 ms
- Frequency focus: 400–2400 Hz (midrange punch)
- Attack: 20 ms (fast click onset)
- Sustain: 80 ms (resonant body)
- Decay: 100 ms (quick falloff)

**Synthesis Method (Recommended):**

**Option A: Synthetic (FM Synthesis or Wavetable)**
- Base oscillator: Sine wave
- Carrier frequency: 800 Hz
- Modulator frequency: 150 Hz
- Modulation index: 4.0 (provides harmonic richness)
- ADSR envelope:
  - Attack: 20 ms
  - Decay: 50 ms
  - Sustain: 0.7 (partial sustain)
  - Release: 100 ms
- Filter: High-pass filter at 300 Hz (removes rumble)
- Resonance: Slight peak at 1500 Hz to add "shine"

**Option B: Sample-Based**
- Layer 1: Sine wave click (800 Hz, 100 ms decay)
- Layer 2: Pitched noise burst (1200–2000 Hz band, 80 ms decay)
- Mix: 70% sine + 30% noise

**Example Tools:**
- **Sonic Pi:** Generate via FM synthesis
- **Supercollider:** Klang or SinOsc + envelope
- **Audacity:** Tone generator + envelope shaping
- **Built-in:** Use Godot's AudioStreamSample + procedural generation

**Variation:** Slight pitch randomization (±50 cents) applied at runtime by AudioManager.

---

## 2. mirror_flip_a.ogg & mirror_flip_b.ogg

**Purpose:** Pair of glass-like toggle sounds for mirror flips.

**Characteristics (both):**
- Duration: 150 ms each
- Frequency focus: 800–3500 Hz (crystalline, minimal bass)
- Attack: 15 ms (crisp onset)
- Sustain: Minimal
- Decay: 60 ms (quick clarity)

**Synthesis Method:**

**mirror_flip_a.ogg (Default pitch):**
- Base oscillator: Sine wave
- Frequency: 2000 Hz
- Modulator: 5 Hz LFO (adds shimmer)
- Modulation amount: 200 Hz (±200 Hz pitch wobble)
- ADSR:
  - Attack: 15 ms
  - Decay: 40 ms
  - Sustain: 0.0 (no sustain)
  - Release: 40 ms
- Filter: High-pass at 600 Hz (removes rumble) + low-pass at 4000 Hz (softens harshness)

**mirror_flip_b.ogg (±100 cents pitch variant):**
- Same as A, but Frequency: 1500 Hz (lower pitch)
- Or use the same synthesis and time-stretch ±6% for natural pitch shift

**Variation Strategy:**
- A and B are played alternately to create a "flip" gesture
- Runtime pitch randomization (±50 cents) can add additional variety

---

## 3. ray_trace.ogg

**Purpose:** Ethereal sweep suggesting light motion; optional juicing sound.

**Characteristics:**
- Duration: 150 ms
- Frequency range: 200–4000 Hz (broad sweep)
- Attack: 30 ms (smooth entry)
- Sustain: 60 ms (taper)
- Decay: 60 ms (soft fade)
- Tone: Upward-sweeping harmonic

**Synthesis Method:**

**Option A: FM Sweep**
- Base oscillator: Sine wave
- Initial frequency: 200 Hz, end frequency: 1500 Hz (linear sweep over 120 ms)
- Modulator: Fixed at 100 Hz
- Modulation index: 3.0 (adds harmonics to the sweep)
- ADSR envelope (applied to amplitude):
  - Attack: 30 ms
  - Decay: 120 ms (taper over duration)

**Option B: Wavetable/Granular**
- Granular synthesis: Use overlapping sine grains, each swept upward
- Grain duration: 40 ms
- Grain spacing: 20 ms (50% overlap)
- Sweep range: 300–2000 Hz per grain, varying by position in output

**Layering (Optional):**
- Layer 1: 200–800 Hz sweep (bass layer, 70%)
- Layer 2: 800–2500 Hz sweep (mid layer, 30%, starts 30 ms after Layer 1)
- Creates a richer, more musical sweep

---

## 4. target_hit_01.ogg, target_hit_02.ogg, target_hit_03.ogg, target_hit_04.ogg

**Purpose:** Pitched bell chimes, one per target; creates chord on multi-target hit.

**Characteristics (all):**
- Duration: 300 ms each
- Attack: 30 ms (gradual bell onset)
- Sustain: 80 ms (resonance)
- Decay: 190 ms (long tail)
- Tone: Harmonic bell-like resonance

**Synthesis Method (Bell Synthesis):**

**Base Algorithm (Karplus-Strong or Modal Synthesis):**
1. Initialize: Short burst of noise (30 ms white noise)
2. Filter: Apply bandpass filter tuned to fundamental frequency
3. Feedback: Recirculate filtered output with slight damping to create ringing tail
4. Harmonics: Add overtones at +1, +2.5, +3 octaves relative to fundamental

**Pitch Assignments (Harmonic Series based on ~200 Hz root):**
- `target_hit_01`: 200 Hz (fundamental)
- `target_hit_02`: 250 Hz (major third above)
- `target_hit_03`: 300 Hz (perfect fifth above)
- `target_hit_04`: 350 Hz (major seventh above, creates warm harmony)

When all four targets light, these four frequencies sound as a chord.

**Synthesis Parameters:**

**For each target_hit_N (substitute frequency):**
- Noise burst: 30 ms white noise at full amplitude
- Bandpass filter:
  - Center frequency: {200, 250, 300, 350} Hz respectively
  - Q (width): 8.0 (narrow, resonant)
- Damping feedback: 0.965 (creates ~300 ms decay)
- Envelope (applied post-synthesis):
  - Attack: Built into noise onset (30 ms)
  - Sustain: 80 ms at full amplitude
  - Decay: 190 ms (exponential)

**Option: Granular Alternative**
- Use short sine grains at target frequency
- Amplitude envelope: Gaussian-shaped grains, spaced 20 ms apart for first 80 ms
- Tail: Extend with lower-amplitude grains (space: 30 ms) for decay phase
- Total grain count: ~12 grains per sound

---

## 5. win.ogg

**Purpose:** Triumphant musical gesture; ascending arpeggio or chord progression.

**Characteristics:**
- Duration: 1000 ms
- Frequency range: 300–5000 Hz (full spectrum)
- Attack: 50 ms (deliberate entry)
- Rise: 200 ms (building tension)
- Sustain: 300 ms (peak moment)
- Decay: 200–400 ms (graceful exit)

**Synthesis Method (Arpeggio/Chord Progression):**

**Structure (4-layer composition):**

**Layer 1: Bass Foundation (300–500 Hz)**
- Duration: 400 ms
- Pitch progression: 200 Hz → 240 Hz (major third)
- Synthesis: FM synthesis (carrier 200 Hz, modulator 50 Hz, depth 2.0)
- Envelope: Attack 50 ms, sustain 200 ms, decay 150 ms
- Purpose: Provides harmonic root and upward motion

**Layer 2: Mid Register (600–1200 Hz)**
- Duration: 600 ms, starts 50 ms into Layer 1
- Pitch: Static 800 Hz (major third of bass)
- Synthesis: Wavetable (sawtooth + pulse blend) into low-pass filter
- Filter cutoff: Sweep 2000 Hz → 3500 Hz over 600 ms (brightness increase)
- Envelope: Attack 30 ms, sustain 400 ms, decay 170 ms
- Purpose: Harmonic richness and upward brightness

**Layer 3: High Accent (2000–4000 Hz)**
- Duration: 500 ms, starts 150 ms into Layer 1
- Pitch: 3000 Hz (harmonic overtone)
- Synthesis: Sine wave with LFO modulation
- LFO: 3 Hz sine wave, ±300 Hz modulation (shimmer effect)
- Envelope: Attack 40 ms, sustain 200 ms, decay 260 ms
- Purpose: Sparkle and resolution

**Layer 4: Reverb/Tail (Optional)**
- Take mix of all three layers
- Apply large reverb: 3.0 second decay, ~60 ms pre-delay
- Reduce layer level to 20% of main mix
- Extends perceived duration to ~1.2 seconds

**Mix Balance:**
- Layer 1: -8 dB
- Layer 2: -6 dB
- Layer 3: -12 dB
- Layer 4 (reverb): -18 dB

**Alternative: Simple 3-Note Arpeggio**
If full synthesis is complex, generate three pure sine tones:
1. 200 Hz: 300 ms (attack 50 ms, decay 250 ms)
2. 300 Hz: 300 ms, starts 100 ms after note 1 (attack 30 ms, decay 270 ms)
3. 400 Hz: 300 ms, starts 200 ms after note 1 (attack 20 ms, decay 280 ms)

Mix at equal loudness; combined sound resolves upward over 500 ms.

---

## 6. level_next.ogg

**Purpose:** Forward-moving bridge between levels; uplifting pitch gesture.

**Characteristics:**
- Duration: 500 ms
- Frequency: 200 Hz → 800 Hz (4-octave rising pitch bend)
- Attack: 40 ms
- Sustain: 200 ms (peak pitch)
- Decay: 100 ms (sharp drop)

**Synthesis Method (Pitch Bend Gesture):**

**Primary Tone:**
- Start frequency: 200 Hz (C3)
- End frequency: 800 Hz (C5)
- Pitch bend duration: 400 ms (linear ramp)
- Synthesis: Sine wave with pitch envelope modulation
- ADSR envelope (amplitude):
  - Attack: 40 ms
  - Decay: 60 ms
  - Sustain: 200 ms
  - Release: 100 ms

**Harmonic Layer (Optional):**
- Add second voice at +1 octave (doubled)
- Same pitch ramp and envelope, 0.5 dB lower volume
- Creates richer, more musical gesture

**Finishing Touch:**
- Small high-frequency "pop" (3000 Hz sine, 50 ms) at peak (400 ms mark)
- Adds "arrival" click at the top of the bend

---

## 7. hover.ogg (Optional)

**Purpose:** Subtle affordance feedback; optional UI enhancement.

**Characteristics:**
- Duration: 100 ms
- Frequency: 1200–2800 Hz (bright, air-like)
- Attack: 10 ms (snappy onset)
- Sustain: Minimal
- Decay: 90 ms (very quick)
- Tone: Minimal pitch content (more shimmer than melody)

**Synthesis Method:**

**Option A: Noise Shimmer**
- White noise burst: 100 ms at 1/3 amplitude
- Band-pass filter: 1200–2800 Hz (Q = 2.0, loose)
- Amplitude envelope: Very fast attack (10 ms), exponential decay (90 ms)
- Result: "Air" sound without melodic pitch

**Option B: High Sine Click**
- Sine wave: 2000 Hz
- Amplitude envelope: 10 ms attack, 90 ms decay
- Slight pitch randomization: ±100 cents (adds shimmer variety)
- LFO (optional): 8 Hz sine, ±150 Hz modulation

**Note:** This sound is optional and can be disabled in settings if it causes mix clutter. Hover feedback is primarily visual; audio is secondary.

---

## Generation Workflow

### Quick Start (Use Existing Samples)

If you don't have synthesis tools available:

1. **Find sample packs:**
   - Freesound.org (CC0/CC-BY licensed)
   - Zapsplat
   - BBC Sound Effects Library
   - Search: "game SFX", "click", "bell", "chime", "whoosh"

2. **Adjust samples:**
   - Use Audacity to trim to specified durations
   - Time-stretch/pitch-shift to match specifications
   - Apply EQ to match frequency ranges

3. **Format:**
   - Export as OGG Vorbis, 44.1 kHz, mono
   - Use quality setting 5–7 (good compression/quality balance)

### Advanced (Procedural Generation in Godot)

Use GDScript + Godot's AudioStreamSample to generate SFX at runtime:

```gdscript
# Example: Generate a simple click sound
var sample = AudioStreamSample.new()
sample.sample_rate = 44100
sample.data = generate_click_audio()  # Your synthesis function
```

See `/godot/AUDIO_GENERATION.gd` for reference implementation.

---

## Quality Checklist

For each placeholder SFX:

- [ ] Duration matches spec (±50 ms acceptable)
- [ ] Frequency range within ±20% of target
- [ ] Attack/decay timing matches description
- [ ] No clipping or distortion (unless intentional)
- [ ] Exported at 44.1 kHz, 16-bit, mono
- [ ] File size < 100 KB per asset
- [ ] Tested in-game at specified volumes (-8 dB, -14 dB, etc.)

---

## Sources & References

**SFX Libraries (if sourcing rather than generating):**
- Freesound.org: Extensive CC-licensed SFX library
- Zapsplat: Free game SFX packs
- OpenGameArt.org: Curated game audio assets
- BBC Sound Effects Library: High-quality, diverse SFX

**Synthesis Tools:**
- REAPER (with ReaJS for synth scripting)
- Sonic Pi (accessible, educational)
- SuperCollider (advanced, powerful)
- Audacity (free, audio editing)
- Web Audio API (browser-based generation)

**Godot Audio References:**
- Official: https://docs.godotengine.org/en/stable/tutorials/audio/
- AudioStream classes: AudioStreamSample, AudioStreamOGGVorbis, AudioStreamMP3
- AudioStreamPlayer: Main playback node

---

## Next Steps

1. **Generate or source** placeholder assets using above specs
2. **Export and organize** into `res://audio/sfx/` directory
3. **Test in-game** by playing Game.gd with AudioManager integrated
4. **Iterate** based on playtester feedback
5. **Polish** with professional sound designer once core mechanics proven

