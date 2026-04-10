# AudioManager.gd — Centralized audio event system for Sight Lines
#
# Manages SFX playback, bus ducking, voice limits, and audio state.
# Integrates with Game.gd to provide sonic feedback for all player actions.
#
# Usage:
#   AudioManager.play_sfx("place_piece")
#   AudioManager.play_sfx("target_hit", pitch_shift=0.8)
#   AudioManager.duck_bus("ambient_sfx", target_db=-20, fade_ms=200)

extends Node

# ── Audio Bus References ──────────────────────────────────────────────────────
var bus_master: int     = AudioServer.get_bus_index("Master")
var bus_ui: int         = AudioServer.get_bus_index("UI")
var bus_ambient: int    = AudioServer.get_bus_index("Ambient SFX")
var bus_music: int      = AudioServer.get_bus_index("Music")

# ── SFX Library (paths mapped to audio asset IDs) ─────────────────────────────
var sfx_library: Dictionary = {
	"place_piece": "res://audio/sfx/place_piece.wav",
	"mirror_flip_a": "res://audio/sfx/mirror_flip_a.wav",
	"mirror_flip_b": "res://audio/sfx/mirror_flip_b.wav",
	"ray_trace": "res://audio/sfx/ray_trace.wav",
	"target_hit_01": "res://audio/sfx/target_hit_01.wav",
	"target_hit_02": "res://audio/sfx/target_hit_02.wav",
	"target_hit_03": "res://audio/sfx/target_hit_03.wav",
	"target_hit_04": "res://audio/sfx/target_hit_04.wav",
	"win": "res://audio/sfx/win.wav",
	"level_next": "res://audio/sfx/level_next.wav",
	"hover": "res://audio/sfx/hover.wav",
}

# ── Voice Tracking (prevent voice-limit overflow) ─────────────────────────────
var active_voices: Dictionary = {}  # {sfx_type: count}
var max_concurrent_voices: int = 8
var voice_priority: Dictionary = {
	"hover": 0,
	"ray_trace": 1,
	"ambient": 2,
	"place_piece": 3,
	"mirror_flip": 4,
	"target_hit": 5,
	"win": 6,
	"level_next": 7,
}

# ── State ─────────────────────────────────────────────────────────────────────
var ducking_state: Dictionary = {}  # {bus_name: {target_db, fade_ms, start_time}}
var is_in_win_state: bool = false

# ── Music Player ──────────────────────────────────────────────────────────────
var music_player: AudioStreamPlayer = null

# ── Init ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Initialize active voice tracking
	for sfx_type: String in voice_priority:
		active_voices[sfx_type] = 0

	# Verify buses exist; create if missing
	_ensure_buses()

	# Create music player
	_create_music_player()

# ── Main API: Play SFX ────────────────────────────────────────────────────────
func play_sfx(sfx_id: String, bus: String = "UI", volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	"""
	Play a sound effect with optional ducking and voice-limit management.

	Args:
		sfx_id: Key from sfx_library (e.g., "place_piece", "target_hit_01")
		bus: Bus to play on ("UI", "Ambient SFX", "Master")
		volume_db: Volume offset from nominal (-8 dB for UI, etc.)
		pitch_scale: Pitch multiplier (1.0 = normal, 0.8 = lower, 1.2 = higher)
	"""
	if sfx_id not in sfx_library:
		push_error("SFX not found: %s" % sfx_id)
		return

	# Voice limit check: if at capacity, kill lowest-priority sound
	if _get_active_voice_count() >= max_concurrent_voices:
		_kill_lowest_priority_voice()

	# Create audio player node
	var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()
	audio_player.bus = bus
	audio_player.volume_db = volume_db
	audio_player.pitch_scale = pitch_scale
	audio_player.stream = load(sfx_library[sfx_id])

	add_child(audio_player)
	audio_player.play()

	# Increment voice counter
	var priority: int = voice_priority.get(sfx_id.split("_")[0], 5)
	active_voices[sfx_id.split("_")[0]] = active_voices.get(sfx_id.split("_")[0], 0) + 1

	# Auto-cleanup when finished
	await audio_player.finished
	audio_player.queue_free()
	active_voices[sfx_id.split("_")[0]] = max(0, active_voices.get(sfx_id.split("_")[0], 1) - 1)

# ── Voice Management ──────────────────────────────────────────────────────────
func _get_active_voice_count() -> int:
	var total: int = 0
	for count: int in active_voices.values():
		total += count
	return total

func _kill_lowest_priority_voice() -> void:
	# Find lowest priority voice currently playing and stop it
	var lowest_sfx: String = ""
	var lowest_priority: int = 999

	for sfx_type: String in active_voices:
		if active_voices[sfx_type] > 0:
			var priority: int = voice_priority.get(sfx_type, 5)
			if priority < lowest_priority:
				lowest_priority = priority
				lowest_sfx = sfx_type

	if lowest_sfx:
		# Kill first child audio player of this type
		for child in get_children():
			if child is AudioStreamPlayer:
				var player_bus: String = AudioServer.get_bus_name(child.bus)
				if lowest_sfx in child.stream.resource_path:
					child.stop()
					child.queue_free()
					active_voices[lowest_sfx] = max(0, active_voices[lowest_sfx] - 1)
					return

# ── Bus Ducking (volume automation) ───────────────────────────────────────────
func duck_bus(bus_name: String, target_db: float, fade_ms: int = 200) -> void:
	"""
	Smoothly transition a bus to target volume over fade_ms milliseconds.

	Args:
		bus_name: "Master", "UI", or "Ambient SFX"
		target_db: Target volume in dB
		fade_ms: Fade duration in milliseconds
	"""
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		push_error("Bus not found: %s" % bus_name)
		return

	ducking_state[bus_name] = {
		"target_db": target_db,
		"fade_ms": fade_ms,
		"start_time": Time.get_ticks_msec(),
		"start_db": AudioServer.get_bus_volume_db(bus_idx),
	}

func unduck_bus(bus_name: String, fade_ms: int = 300) -> void:
	"""Restore a bus to its nominal volume."""
	var nominal_db: float = {
		"Master": 0.0,
		"UI": -8.0,
		"Ambient SFX": -14.0,
		"Music": -12.0,
	}.get(bus_name, 0.0)

	duck_bus(bus_name, nominal_db, fade_ms)

# ── Win State Ducking ─────────────────────────────────────────────────────────
func on_win_state_enter() -> void:
	"""Call when puzzle is solved and win overlay appears."""
	is_in_win_state = true

	# Duck background audio to highlight win sound
	duck_bus("Ambient SFX", -20.0, 200)
	duck_bus("UI", -11.0, 200)
	duck_bus("Music", -20.0, 200)

	# Play win sound
	play_sfx("win", "Master", -4.0)

func on_win_state_exit() -> void:
	"""Call when advancing to next level."""
	is_in_win_state = false

	# Restore ducked buses
	unduck_bus("Ambient SFX", 300)
	unduck_bus("UI", 300)
	unduck_bus("Music", 300)

# ── Event Triggers (called from Game.gd) ──────────────────────────────────────
func evt_piece_placed() -> void:
	"""Trigger: Piece placed in empty slot."""
	# Random pitch variation for variation (±50 cents ≈ ±2.38% pitch)
	var pitch: float = randf_range(0.98, 1.02)
	play_sfx("place_piece", "UI", -8.0, pitch)

func evt_mirror_flipped() -> void:
	"""Trigger: Mirror state toggled (/ ↔ \\)."""
	var flip_sound: String = ["mirror_flip_a", "mirror_flip_b"].pick_random()
	play_sfx(flip_sound, "UI", -11.0)

func evt_ray_updated() -> void:
	"""Trigger: Ray path recalculated after placement or flip."""
	# Optional; skip if mix feels clean without it
	play_sfx("ray_trace", "Ambient SFX", -14.0)

func evt_target_lit(target_index: int = 0) -> void:
	"""
	Trigger: Target transitions from dark to lit.

	Args:
		target_index: Which target is lighting (0–3), determines pitch
	"""
	var target_sfx: String = "target_hit_%02d" % [(target_index % 4) + 1]
	var stagger_ms: int = target_index * 15  # Slight stagger between multiple hits

	# Play with slight delay for staggered multi-target effect
	await get_tree().create_timer(stagger_ms / 1000.0).timeout
	play_sfx(target_sfx, "Master", -5.0)

func evt_level_complete() -> void:
	"""Trigger: All targets lit, win state entered."""
	on_win_state_enter()

func evt_advance_level() -> void:
	"""Trigger: Player clicks to advance to next level."""
	# Fade out win sound as level-next sound enters
	play_sfx("level_next", "Master", -6.0)
	await get_tree().create_timer(0.1).timeout
	on_win_state_exit()

func evt_hover_valid_slot() -> void:
	"""Trigger: Mouse hovers over valid placement slot (optional, subtle)."""
	# Uncomment to enable; currently commented as optional
	# play_sfx("hover", "UI", -16.0)
	pass

# ── Music Control (ambient loop) ──────────────────────────────────────────────
func _create_music_player() -> void:
	"""Create and configure the music player for ambient loop."""
	if music_player:
		music_player.queue_free()

	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.volume_db = -12.0
	music_player.stream = load("res://audio/music/ambient_loop.ogg")
	add_child(music_player)

func evt_music_start() -> void:
	"""Start ambient music loop."""
	if not music_player:
		_create_music_player()

	if music_player and not music_player.playing:
		music_player.play()
		print("AudioManager: Ambient music loop started")

func evt_music_stop() -> void:
	"""Stop ambient music loop with fade-out."""
	if music_player and music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80.0, 0.5)
		tween.tween_callback(func(): if music_player: music_player.stop())
		print("AudioManager: Ambient music loop stopped")

# ── Bus Maintenance ──────────────────────────────────────────────────────────
func _ensure_buses() -> void:
	"""Create missing audio buses if they don't exist."""
	if AudioServer.get_bus_index("UI") == -1:
		var new_bus: int = AudioServer.get_bus_count()
		AudioServer.add_bus(new_bus)
		AudioServer.set_bus_name(new_bus, "UI")
		AudioServer.set_bus_volume_db(new_bus, -8.0)

	if AudioServer.get_bus_index("Ambient SFX") == -1:
		var new_bus: int = AudioServer.get_bus_count()
		AudioServer.add_bus(new_bus)
		AudioServer.set_bus_name(new_bus, "Ambient SFX")
		AudioServer.set_bus_volume_db(new_bus, -14.0)

	if AudioServer.get_bus_index("Music") == -1:
		var new_bus: int = AudioServer.get_bus_count()
		AudioServer.add_bus(new_bus)
		AudioServer.set_bus_name(new_bus, "Music")
		AudioServer.set_bus_volume_db(new_bus, -12.0)

# ── Update Loop (for bus ducking automation) ──────────────────────────────────
func _process(_delta: float) -> void:
	# Process active bus ducking
	var current_time: int = Time.get_ticks_msec()

	for bus_name: String in ducking_state.keys():
		var state: Dictionary = ducking_state[bus_name]
		var elapsed: int = current_time - state["start_time"]
		var fade_ms: int = state["fade_ms"]

		if elapsed >= fade_ms:
			# Ducking complete
			var bus_idx: int = AudioServer.get_bus_index(bus_name)
			AudioServer.set_bus_volume_db(bus_idx, state["target_db"])
			ducking_state.erase(bus_name)
		else:
			# Interpolate volume
			var t: float = float(elapsed) / float(fade_ms)
			var volume: float = lerp(state["start_db"], state["target_db"], t)
			var bus_idx: int = AudioServer.get_bus_index(bus_name)
			AudioServer.set_bus_volume_db(bus_idx, volume)
