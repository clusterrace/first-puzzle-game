# Ambient Music Specification — Sight Lines

## 1. Design Intent

**Purpose:** Provide atmospheric background music that supports the puzzle-solving experience without distracting from the core gameplay mechanics.

**Sonic Direction:** Minimal, contemplative, puzzle-appropriate. Suggest calm focus and intellectual engagement. No aggressive or sudden dynamic shifts.

**Mix Priority:** Ambient music sits BELOW SFX feedback hierarchy. When a sound effect plays (placement, win, etc.), the music remains present but recedes.

---

## 2. Music Specification

### 2.1 Ambient Music Loop — Gameplay & Menu

**Identifier:** `music_ambient_loop`

**Purpose:** Seamless looping background track for both main menu and in-game puzzle solving.

**Characteristics:**
- **Duration:** 30–60 seconds per loop (ideally 60s for imperceptible looping)
- **Tone:** Ambient, minimalist, puzzle-appropriate
- **Instrumentation:** Synthetic or purely digital (avoid acoustic instruments to maintain clarity with UI sounds)
- **Tempo:** Slow, ~60–80 BPM or no clear pulse (floating, meditative)
- **Harmonic center:** A minor, C major, or D minor (consonant, non-threatening)
- **Frequency balance:** Emphasis on mid-range (500–2000 Hz); avoid bass rumble and high-frequency artifacts

**Required Qualities:**
- **Seamless loop:** No audible discontinuity at the loop point; waveform must fade/crossfade appropriately
- **Dynamic stability:** Avoid sudden swells, drops, or surprises; constant, predictable texture
- **Compatibility:** Must sit cleanly under UI SFX without competing
- **Mono or stereo:** Stereo acceptable; mono fine; no spatial effects that distract

**Behavior:**
- **Trigger:** Auto-play when game starts (main menu or level load)
- **Looping:** Continuous crossfade to next loop iteration (no hard silence)
- **Volume:** -12 dB nominal (bus: Music), ducks to -20 dB during SFX spikes
- **Falloff:** If music cannot load, gameplay continues silently (no error state)

**Notes:** This is the only active music track in the prototype. A single well-designed loop is superior to multiple variants that create inconsistency.

---

## 3. Audio Bus Architecture

### 3.1 Music Bus (New)

Add a new bus to the audio hierarchy:

```
Master (0 dB)
├── UI (-8 dB nominal, ducks to -11 dB during win)
├── Ambient SFX (-14 dB nominal, ducks to -20 dB during win)
└── Music (-12 dB nominal, ducks to -18 dB during win & target hits)
```

**Bus Settings:**
- **Initial volume:** -12 dB
- **Mono/Stereo:** Stereo (to support spatial panning in future)
- **Effects:** None (keep clean)
- **Ducking:** See section 3.2

### 3.2 Ducking Rules

**When SFX active (target hit, win, level complete):**
- Music: -12 dB → -18 dB (additional -6 dB duck)
- Fade time: 100 ms in, 200 ms out
- Effect: Music softly recedes, SFX takes focus

**When win state active (level complete overlay):**
- Music: -12 dB → -20 dB (additional -8 dB duck)
- UI: -8 dB → -11 dB (additional -3 dB)
- Ambient SFX: -14 dB → -20 dB (additional -6 dB)
- Fade time: 200 ms in, 300 ms out
- Effect: All background audio quiets; win celebration stands alone

---

## 4. Implementation in AudioManager

### 4.1 Music Event

Add to the AudioManager event catalog:

| Event ID | Trigger Condition | Asset | Volume | Bus | Concurrency | Priority |
|---|---|---|---|---|---|---|
| `EVT_MUSIC_LOOP` | Game/level starts; auto-repeat on loop end | music_ambient_loop | -12 dB | Music | 1 voice | Low |

### 4.2 GDScript Integration (AudioManager.gd)

Pseudocode to add music support:

```gdscript
# In AudioManager class:

## Music bus reference
var music_bus_index: int = -1

## Current music track (AudioStreamPlayer for continuous looping)
var music_player: AudioStreamPlayer = null

func _ready():
    # ... existing code ...
    music_bus_index = AudioServer.get_bus_index("Music")
    _ensure_bus("Music", -12.0)  # Ensure Music bus exists
    _create_music_player()

func _create_music_player() -> void:
    """Create and configure the music player."""
    if music_player:
        music_player.queue_free()
    
    music_player = AudioStreamPlayer.new()
    music_player.bus = "Music"
    music_player.stream = load("res://audio/music/ambient_loop.ogg")
    add_child(music_player)

func evt_music_loop_start() -> void:
    """Start ambient music loop."""
    if not music_player:
        _create_music_player()
    
    if not music_player.playing:
        music_player.play()
        print("Music: ambient loop started")

func evt_music_loop_stop() -> void:
    """Stop ambient music loop."""
    if music_player and music_player.playing:
        var tween = create_tween()
        tween.tween_property(music_player, "volume_db", -80, 0.5)
        tween.tween_callback(func(): music_player.stop())
        print("Music: ambient loop stopped")

func evt_music_duck(target_db: float = -18.0, fade_time: float = 0.1) -> void:
    """Duck music volume during SFX."""
    var tween = create_tween()
    tween.tween_property(music_player, "volume_db", target_db, fade_time)

func evt_music_unduck(fade_time: float = 0.2) -> void:
    """Return music to nominal volume."""
    var tween = create_tween()
    tween.tween_property(music_player, "volume_db", -12.0, fade_time)
```

### 4.3 Trigger Points in Game.gd

Add music event calls at these locations:

| Location | Trigger | Call |
|---|---|---|
| `_ready()` | Game initializes | `AudioManager.evt_music_loop_start()` |
| `load_level()` | Level loads | `AudioManager.evt_music_loop_start()` |
| Target hit (line ~198) | Target illuminates | `AudioManager.evt_music_duck(-18.0, 0.1)` then `evt_music_unduck(0.2)` |
| Win state (line ~170) | `win = true` | `AudioManager.evt_music_duck(-20.0, 0.2)` |
| Win state exit | New level starts | `AudioManager.evt_music_unduck(0.3)` |

---

## 5. Asset Specification

### 5.1 Audio File Details

| Asset | Format | Sample Rate | Channels | Duration | Bitrate | File Size | Location |
|---|---|---|---|---|---|---|---|
| `ambient_loop` | OGG Vorbis | 44.1 kHz | Stereo | 60 s | 128 kbps | ~960 KB | `res://audio/music/ambient_loop.ogg` |

### 5.2 Creation Guidelines

**For generated/synthesized music:**
1. Create a 60-second seamless loop in a DAW (Reaper, Ableton, Audacity, etc.)
2. Use soft, sustained pad sounds; avoid percussion or rhythmic elements
3. Ensure waveform envelope is smooth at start/end (gentle fade to silence within 100 ms of boundaries)
4. Export as WAV (lossless working copy)
5. Convert to OGG Vorbis at quality 6–7 (good compression/quality balance)
6. Test in Godot: play twice back-to-back; listen for seams at the loop point

**For sourced/licensed music:**
- Verify seamless looping capability before licensing
- Confirm web export compatibility (OGG support)
- Ensure tempo/mood matches puzzle game aesthetic

---

## 6. Mixing Parameters

### 6.1 Volume Targets

| State | Music dB | UI dB | Ambient SFX dB | Master dB | Notes |
|---|---|---|---|---|---|
| Nominal gameplay | -12 | -8 | -14 | 0 | Baseline mix |
| During target hit | -18 | -8 | -14 | 0 | Music ducks slightly |
| During win state | -20 | -11 | -20 | 0 | All background audio recedes |
| Menu | -12 | -8 | -14 | 0 | Same as gameplay |
| Music absent (fallback) | silent | -8 | -14 | 0 | Game continues without music |

### 6.2 Fade Times

| Transition | Duration | Curve |
|---|---|---|
| Music start (game load) | 500 ms | Linear |
| Music duck (target hit) | 100 ms in, 200 ms out | Linear |
| Music duck (win state) | 200 ms in, 300 ms out | Linear |
| Music fade-out (level end) | 500 ms | Linear |
| Music loop crossfade | Seamless (baked into asset) | N/A |

---

## 7. Placeholder Generation Instructions

### 7.1 Quick Placeholder (Audacity)

1. **Create ambient pad:**
   - New 60-second mono track at 44.1 kHz
   - Generate: Tone with frequency 110 Hz (A2), sine wave
   - Smooth ADSR: Attack 500 ms, Decay 500 ms, Sustain -12 dB, Release 100 ms
   - Result: Gentle hum that fades in/out smoothly

2. **Add texture (optional):**
   - Generate white noise (1–2 seconds)
   - Reduce volume to -24 dB
   - Apply high-pass filter (cut below 500 Hz)
   - Reverse, compress, layer under tone
   - Result: Subtle shimmer

3. **Final prep:**
   - Normalize to -6 dB peak (leave headroom)
   - Fade in/out at boundaries (250 ms soft fade, linear)
   - Export as WAV (32-bit PCM, 44.1 kHz)
   - Convert to OGG Vorbis (quality 6): `ffmpeg -i ambient.wav -q:a 6 ambient.ogg`

### 7.2 Web Audio API Alternative

For browser-based placeholder:
- Use oscillator + filter to create generative ambient tone
- Save final mix as OGG for Godot import
- Recommended tool: Tone.js or Web Audio API direct

---

## 8. Testing Checklist

- [ ] Music file exists at `res://audio/music/ambient_loop.ogg`
- [ ] Music bus created in Godot Audio panel with -12 dB init
- [ ] AudioManager._create_music_player() successfully loads asset
- [ ] Music plays on game start (main menu or level load)
- [ ] Music continues looping without audible seams after 60 seconds
- [ ] Pause/resume does not cause audio glitches
- [ ] Music volume is audible but not dominant (~-12 dB)
- [ ] SFX (win, target hit) are clearly audible over music
- [ ] Music ducks appropriately during target hits and win state
- [ ] No crackling, pops, or artifacts at loop boundaries
- [ ] Web export (HTML5) correctly plays OGG without errors

---

## 9. Future Enhancements

1. **Adaptive music:** Vary intensity based on puzzle difficulty or time-to-solve
2. **Multiple loops:** Different tracks for menu vs. gameplay (creates variety)
3. **Dynamic mixing:** Music responds to player actions (target hits trigger subtle swells)
4. **Level-specific variants:** Each level/stage gets a unique ambient track
5. **Silence option:** Add "Mute Music" toggle to main menu settings

---

## 10. References

- **Godot Audio Docs:** https://docs.godotengine.org/en/stable/tutorials/audio/
- **Audacity:** https://www.audacityteam.org/
- **FFmpeg:** https://ffmpeg.org/
- **OGG Vorbis Quality Guide:** https://wiki.xiph.org/Vorbis/FAQ/Tuning

---

## Audio Designer Notes

**From Sound Designer (Paperclip Agent 33b302ad):**

This specification provides everything needed to integrate a single, seamless ambient music loop into Sight Lines. The music is intentionally minimal and non-intrusive—it supports the puzzle-solving experience without competing with SFX feedback.

**Key principles:**
1. **Music is background.** It never dominates. SFX feedback (clicks, wins, target hits) always takes priority.
2. **Seamless looping is critical.** A 60-second loop with audible seams breaks immersion. Invest time in smooth fade-in/fade-out at boundaries.
3. **Ducking preserves clarity.** When celebrations happen (target hits, win state), music softly recedes so the player hears the moment clearly.
4. **Mono or stereo both work.** For a puzzle game, the difference is minimal. Mono saves bandwidth; stereo feels slightly richer.

**When commissioning professional music:**
- Provide this spec to the composer.
- Ask for a 60-second seamless loop in A minor or C major.
- Request multiple takes if the first feels too energetic or too sparse.
- Test in-engine with actual SFX before final approval.

---

**Created:** 2026-04-10  
**Audio System Version:** 1.0  
**Status:** Specification Complete (Awaiting Asset Implementation)

