# RayRenderer.gd — Production sight-ray visualization  (KAMA-20)
# Purpose: Manages a pool of Line2D nodes, each carrying the ray_beam
#          ShaderMaterial, to render sight rays with an additive glow effect.
#          Pure rendering layer — holds no game state, drives no logic.
#
# Integration (Game.gd or future S2 signal bus):
#   Call refresh(segments) whenever ray paths change.
#   Call clear() when a level is loaded before new data arrives.
#
# Signal contract expected from KAMA-16 / KAMA-17 (wire up externally):
#   signal rays_changed(segments: Array)  →  RayRenderer.refresh(segments)
#
# segments format — same as Game.ray_segs prototype:
#   Array of Dictionary: [{ "from": Vector2, "to": Vector2 }, ...]
extends Node2D

const _SHADER_PATH  := "res://shaders/ray_beam.gdshader"
const _BEAM_WIDTH   := 28.0   # px — outer glow diameter; core is ~12% of this
const _POOL_STEP    := 8      # grow pool in chunks to avoid per-frame allocations

var _pool : Array[Line2D] = []
var _mat  : ShaderMaterial
var _uv_tex : ImageTexture  # 1×1 white pixel — forces Line2D UV generation

func _ready() -> void:
	# Shared material — all rays use identical uniforms (same shader settings).
	_mat = ShaderMaterial.new()
	_mat.shader = load(_SHADER_PATH)

	# A 1×1 white texture assigned to every Line2D forces Godot's renderer to
	# generate UV coordinates across the line width, enabling the cross-width
	# glow gradient in ray_beam.gdshader (UV.y = 0..1 across beam width).
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_uv_tex = ImageTexture.create_from_image(img)


# ── Public API ────────────────────────────────────────────────────────────────

## Replace all rendered ray segments with the new list.
## Call this every time the ray path changes (after any piece placement/removal).
func refresh(segments: Array) -> void:
	_ensure_pool(segments.size())
	for i: int in range(segments.size()):
		var seg: Dictionary = segments[i]
		_pool[i].points  = PackedVector2Array([seg["from"], seg["to"]])
		_pool[i].visible = true
	# Hide any pooled lines not in use this frame.
	for i: int in range(segments.size(), _pool.size()):
		_pool[i].visible = false


## Hide all rays (call when loading a new level before data arrives).
func clear() -> void:
	for line: Line2D in _pool:
		line.visible = false


# ── Pool management ───────────────────────────────────────────────────────────

func _ensure_pool(needed: int) -> void:
	if _pool.size() >= needed:
		return
	# Round up to the next chunk boundary to amortise allocation cost.
	var target := int(ceil(float(needed) / _POOL_STEP)) * _POOL_STEP
	while _pool.size() < target:
		var line := Line2D.new()
		line.width          = _BEAM_WIDTH
		line.default_color  = Color.WHITE   # shader controls actual colour
		line.texture        = _uv_tex       # triggers UV generation
		line.texture_mode   = Line2D.LINE_TEXTURE_STRETCH
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode   = Line2D.LINE_CAP_ROUND
		line.material       = _mat          # shared — OK since uniforms are identical
		line.visible        = false
		add_child(line)
		_pool.append(line)
