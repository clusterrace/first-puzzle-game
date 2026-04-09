# Audio System Integration Guide

## Overview

This guide walks through integrating the AudioManager system into Game.gd to trigger sound effects at the correct moments during gameplay.

**Prerequisites:**
- AudioManager.gd placed in `scripts/` directory
- Audio assets (.ogg files) in `audio/sfx/` directory
- Godot audio buses configured (or auto-created by AudioManager)

---

## Step 1: Add AudioManager to Game Scene

### Option A: Autoload (Recommended)

In Godot Editor:
1. Project → Project Settings → Autoload tab
2. Add `scripts/AudioManager.gd` as an autoload singleton named `AudioManager`
3. This makes `AudioManager` globally accessible from any script

**Result:** Access from Game.gd as:
```gdscript
AudioManager.play_sfx("place_piece")
```

### Option B: Scene Node

Add AudioManager as a child of the Game node:

```gdscript
# In Game.gd _ready():
var audio_mgr = AudioManager.new()
add_child(audio_mgr)
audio_manager = audio_mgr
```

Then call:
```gdscript
audio_manager.evt_piece_placed()
```

**We'll use Option A (Autoload) below.**

---

## Step 2: Modify Game.gd to Trigger Audio Events

Insert the following calls at the specified locations in Game.gd:

### 2.1 Piece Placement (Line ~250)

**Current code:**
```gdscript
if t == SLOT and hand.size() > 0:
    var piece: int = hand[0]
    hand.remove_at(0)
    grid[r][c] = piece
    if piece == OBS:
        obs_dirs[Vector2i(r, c)] = RT
    _update_rays()
```

**Modified code:**
```gdscript
if t == SLOT and hand.size() > 0:
    var piece: int = hand[0]
    hand.remove_at(0)
    grid[r][c] = piece
    if piece == OBS:
        obs_dirs[Vector2i(r, c)] = RT
    
    # AUDIO: Piece placement confirmation
    AudioManager.evt_piece_placed()
    
    _update_rays()
    
    # AUDIO: Ray update sound (optional)
    AudioManager.evt_ray_updated()
```

### 2.2 Mirror Flip (Lines ~254–259)

**Current code:**
```gdscript
elif t == MIR_F:
    grid[r][c] = MIR_B
    _update_rays()
elif t == MIR_B:
    grid[r][c] = MIR_F
    _update_rays()
```

**Modified code:**
```gdscript
elif t == MIR_F:
    grid[r][c] = MIR_B
    
    # AUDIO: Mirror flip confirmation
    AudioManager.evt_mirror_flipped()
    
    _update_rays()
    
    # AUDIO: Ray update sound (optional)
    AudioManager.evt_ray_updated()

elif t == MIR_B:
    grid[r][c] = MIR_F
    
    # AUDIO: Mirror flip confirmation
    AudioManager.evt_mirror_flipped()
    
    _update_rays()
    
    # AUDIO: Ray update sound (optional)
    AudioManager.evt_ray_updated()
```

### 2.3 Target Illumination (Lines ~158–159, in `_update_rays()`)

**Current code:**
```gdscript
for r in range(ROWS):
    for c in range(COLS):
        if grid[r][c] == TGT:
            lit[Vector2i(r, c)] = false
```

**Add target hit tracking:**
```gdscript
var newly_lit_targets: Array[Vector2i] = []

for r in range(ROWS):
    for c in range(COLS):
        if grid[r][c] == TGT:
            lit[Vector2i(r, c)] = false
```

**Then modify ray trace to record new hits (Line ~198):**

**Current code:**
```gdscript
elif t == TGT:
    ray_segs.append({"from": prev, "to": cur})
    lit[Vector2i(nr, nc)] = true
    break
```

**Modified code:**
```gdscript
elif t == TGT:
    ray_segs.append({"from": prev, "to": cur})
    var target_pos = Vector2i(nr, nc)
    if not lit[target_pos]:  # First time this target lights
        newly_lit_targets.append(target_pos)
    lit[target_pos] = true
    break
```

**At end of `_update_rays()`, before win check:**

```gdscript
    # AUDIO: Play target hit sounds for newly illuminated targets
    for i in range(newly_lit_targets.size()):
        AudioManager.evt_target_lit(i)  # Staggered playback handled in AudioManager
```

### 2.4 Win State (Lines ~165–171)

**Current code:**
```gdscript
var all_lit := lit.size() > 0
for cell: Vector2i in lit.keys():
    if not lit[cell]:
        all_lit = false
        break
win = all_lit
queue_redraw()
```

**Modified code:**
```gdscript
var all_lit := lit.size() > 0
for cell: Vector2i in lit.keys():
    if not lit[cell]:
        all_lit = false
        break

# AUDIO: Trigger win celebration on state change
if all_lit and not win:
    AudioManager.evt_level_complete()

win = all_lit
queue_redraw()
```

### 2.5 Level Advance (Line ~229)

**Current code:**
```gdscript
if event is InputEventMouseButton and event.pressed:
    var next := (level_idx + 1) % LEVELS.size()
    load_level(next)
    return
```

**Modified code:**
```gdscript
if event is InputEventMouseButton and event.pressed:
    var next := (level_idx + 1) % LEVELS.size()
    
    # AUDIO: Level transition sound
    await AudioManager.evt_advance_level()
    
    load_level(next)
    return
```

### 2.6 Hover Feedback (Optional, Line ~236)

**Current code:**
```gdscript
if event is InputEventMouseMotion:
    var cell := screen_to_cell(event.position)
    if cell != hover_cell:
        hover_cell = cell
        queue_redraw()
```

**Modified code (if hover feedback enabled):**
```gdscript
if event is InputEventMouseMotion:
    var cell := screen_to_cell(event.position)
    if cell != hover_cell:
        hover_cell = cell
        
        # AUDIO: Subtle hover feedback over valid slots (optional)
        if in_bounds(cell.x, cell.y) and grid[cell.x][cell.y] == SLOT and hand.size() > 0:
            AudioManager.evt_hover_valid_slot()
        
        queue_redraw()
```

---

## Step 3: Create Audio Buses in Godot

**Option A: Programmatic (Automatic)**

AudioManager creates missing buses automatically on `_ready()`. No manual setup needed.

**Option B: Editor-Based (Recommended for fine-tuning)**

1. Open **Audio** panel in Godot Editor (if not visible: Window → Audio)
2. Right-click audio bus tree → Add Bus
3. Create three buses with these names:
   - `UI` (child of Master, initial volume: -8 dB)
   - `Ambient SFX` (child of Master, initial volume: -14 dB)

4. Set initial volumes:
   - Select `UI` bus → Volume parameter → set to -8 dB
   - Select `Ambient SFX` bus → Volume parameter → set to -14 dB

**Verify:** In AudioManager.gd, lines 8–10 reference these buses by name.

---

## Step 4: Create Audio Asset Directory and Test Stubs

Create placeholder audio files for testing:

```bash
# In project root
mkdir -p audio/sfx

# Generate silent test files (44.1 kHz, 1 sec each, OGG format)
# Using command-line tools or Audacity batch export

# Or create minimal valid OGG files:
# (Requires audio software; see PLACEHOLDER_SFX_SPECS.md for generation methods)
```

**For now, use silent/dummy assets** to test system integration without audio content.

---

## Step 5: Full Integration Example

Here's the complete modified `_update_rays()` and input handling:

```gdscript
func _update_rays() -> void:
    ray_segs = []
    lit = {}
    var newly_lit_targets: Array[Vector2i] = []
    
    for r in range(ROWS):
        for c in range(COLS):
            if grid[r][c] == TGT:
                lit[Vector2i(r, c)] = false

    for cell: Vector2i in obs_dirs.keys():
        if in_bounds(cell.x, cell.y) and grid[cell.x][cell.y] == OBS:
            _trace_ray(cell.x, cell.y, obs_dirs[cell])

    # Track newly illuminated targets for audio feedback
    for r in range(ROWS):
        for c in range(COLS):
            if grid[r][c] == TGT:
                var target_pos = Vector2i(r, c)
                if not lit.get(target_pos, false) and lit.get(target_pos, false):
                    newly_lit_targets.append(target_pos)

    var all_lit := lit.size() > 0
    for cell: Vector2i in lit.keys():
        if not lit[cell]:
            all_lit = false
            break

    # AUDIO: Win state change
    if all_lit and not win:
        AudioManager.evt_level_complete()

    win = all_lit
    
    # AUDIO: Target hit sounds
    for i in range(newly_lit_targets.size()):
        AudioManager.evt_target_lit(i)
    
    queue_redraw()


func _trace_ray(sr: int, sc: int, dir: int) -> void:
    var r := sr
    var c := sc
    var d := dir
    var prev := cell_center(r, c)

    for _step in range(ROWS * COLS * 2):
        var dv: Vector2i = DIR_V[d]
        var nr := r + dv.y
        var nc := c + dv.x

        if not in_bounds(nr, nc):
            var next := cell_center(nr, nc)
            ray_segs.append({"from": prev, "to": prev.lerp(next, 0.5)})
            break

        var cur := cell_center(nr, nc)
        var t: int = grid[nr][nc]

        if t == WALL:
            ray_segs.append({"from": prev, "to": prev.lerp(cur, 0.5)})
            break
        elif t == TGT:
            ray_segs.append({"from": prev, "to": cur})
            lit[Vector2i(nr, nc)] = true
            break
        elif t == MIR_F or t == MIR_B:
            ray_segs.append({"from": prev, "to": cur})
            d = _reflect(d, t == MIR_F)
            r = nr; c = nc; prev = cur
        else:
            ray_segs.append({"from": prev, "to": cur})
            r = nr; c = nc; prev = cur


func _input(event: InputEvent) -> void:
    if win:
        if event is InputEventMouseButton and event.pressed:
            var next := (level_idx + 1) % LEVELS.size()
            
            # AUDIO: Level advance
            AudioManager.evt_advance_level()
            
            # Small delay to let audio play
            await get_tree().create_timer(0.2).timeout
            
            load_level(next)
        return

    if event is InputEventMouseMotion:
        var cell := screen_to_cell(event.position)
        if cell != hover_cell:
            hover_cell = cell
            queue_redraw()

    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var cell := screen_to_cell(event.position)
        if not in_bounds(cell.x, cell.y):
            return
        var r := cell.x
        var c := cell.y
        var t: int = grid[r][c]

        if t == SLOT and hand.size() > 0:
            var piece: int = hand[0]
            hand.remove_at(0)
            grid[r][c] = piece
            if piece == OBS:
                obs_dirs[Vector2i(r, c)] = RT
            
            # AUDIO: Piece placement
            AudioManager.evt_piece_placed()
            
            _update_rays()
            # Ray update sound already triggered in _update_rays()
            
        elif t == MIR_F:
            grid[r][c] = MIR_B
            
            # AUDIO: Mirror flip
            AudioManager.evt_mirror_flipped()
            
            _update_rays()
            # Ray update sound already triggered in _update_rays()
            
        elif t == MIR_B:
            grid[r][c] = MIR_F
            
            # AUDIO: Mirror flip
            AudioManager.evt_mirror_flipped()
            
            _update_rays()
            # Ray update sound already triggered in _update_rays()
```

---

## Step 6: Test Integration

1. **Verify buses exist:** Open Godot Editor → Audio panel → confirm "UI" and "Ambient SFX" buses
2. **Play game:** Run main scene
3. **Check console:** No errors should appear in Output panel
4. **Audio playback:** You should hear (or silent test files play if audio not yet created)
5. **Adjust volumes:** If sounds too loud/quiet, modify `AudioManager.play_sfx()` calls' volume parameters

---

## Debugging Checklist

| Issue | Solution |
|---|---|
| **Audio not playing** | Check sfx file paths in AudioManager.sfx_library match actual files in res://audio/sfx/ |
| **"Bus not found" error** | Ensure buses created: Project Settings → Autoload or Editor Audio panel |
| **Voices cutting off** | Increase max_concurrent_voices in AudioManager (default: 8) |
| **Audio too loud/quiet** | Adjust volume_db parameters in AudioManager.evt_* functions or bus volumes |
| **Audible pops/clicks** | Ensure audio assets have proper envelope (no sharp discontinuities) |
| **Win sound not playing** | Verify `evt_level_complete()` called when win=true; check win overlay renders |

---

## Next Steps

1. ✅ AudioManager.gd implemented and integrated
2. ✅ Audio events wired into Game.gd
3. ⏳ **Generate or source placeholder SFX** (see PLACEHOLDER_SFX_SPECS.md)
4. ⏳ **Place audio files** in res://audio/sfx/
5. ⏳ **Playtest and tune** volumes and timings based on feedback
6. ⏳ **Commission professional SFX** once core mechanics validated

---

## Audio Memory Budget

**Estimated runtime memory (with all assets):**
- 11 audio files × 150 KB average = ~1.65 MB
- Safe margin: ≤5 MB for audio subsystem
- Voice budget: 8 simultaneous voices (standard polyphony for puzzle game)

**No streaming required** for prototype; all SFX fit comfortably in memory.

