# TargetRenderer.gd — Production target-tile visualization  (KAMA-20)
# Purpose: Creates one ColorRect per target cell, each with its own instance of
#          the target_tile ShaderMaterial.  Drives `lit` and `win_pulse`
#          uniforms in response to game state — no logic lives here.
#
# Integration (Game.gd or future S2 signal bus):
#   Call setup(pad_x, pad_y, cell_size) once per load — positions the rects.
#   Call set_targets(target_cells)      to create / replace target visuals.
#   Call set_lit(cell, is_lit)          per target when state changes.
#   Call set_win_pulse(active)          to start / stop the win animation.
#   Call clear()                        when loading a new level.
#
# Signal contract expected from KAMA-16 / KAMA-17 (wire up externally):
#   signal level_loaded(target_cells: Array[Vector2i])
#     → TargetRenderer.set_targets(target_cells)
#   signal target_state_changed(cell: Vector2i, is_lit: bool)
#     → TargetRenderer.set_lit(cell, is_lit)
#   signal win_achieved()
#     → TargetRenderer.set_win_pulse(true)
extends Node2D

const _SHADER_PATH := "res://shaders/target_tile.gdshader"

# Board geometry — set once via setup().
var _pad_x     : float = 40.0
var _pad_y     : float = 50.0
var _cell_size : int   = 80

# Map from grid cell (Vector2i row,col) → { rect: ColorRect, mat: ShaderMaterial }
var _targets : Dictionary = {}


# ── Lifecycle ─────────────────────────────────────────────────────────────────

## Call once (or on window resize) to align visual nodes with the board.
func setup(pad_x: float, pad_y: float, cell_size: int) -> void:
	_pad_x     = pad_x
	_pad_y     = pad_y
	_cell_size = cell_size


# ── Public API ────────────────────────────────────────────────────────────────

## Rebuild target visuals from a list of grid cells.
## target_cells: Array[Vector2i] where .x = row, .y = col  (matches Game.gd convention)
func set_targets(target_cells: Array) -> void:
	clear()
	for cell: Vector2i in target_cells:
		_create_target_node(cell)


## Update the lit state of one target.  Safe to call with non-target cells.
func set_lit(cell: Vector2i, is_lit: bool) -> void:
	if not _targets.has(cell):
		return
	var mat: ShaderMaterial = _targets[cell]["mat"]
	mat.set_shader_parameter("lit", 1.0 if is_lit else 0.0)


## Activate or deactivate the win-pulse animation on all targets.
func set_win_pulse(active: bool) -> void:
	var v := 1.0 if active else 0.0
	for cell: Vector2i in _targets.keys():
		var mat: ShaderMaterial = _targets[cell]["mat"]
		mat.set_shader_parameter("win_pulse", v)


## Remove all target visuals (call before loading a new level).
func clear() -> void:
	for cell: Vector2i in _targets.keys():
		var rect: ColorRect = _targets[cell]["rect"]
		rect.queue_free()
	_targets.clear()


# ── Internal ──────────────────────────────────────────────────────────────────

func _create_target_node(cell: Vector2i) -> void:
	var r   := cell.x
	var c   := cell.y
	var pos := Vector2(_pad_x + c * _cell_size, _pad_y + r * _cell_size)

	# Each target gets its OWN ShaderMaterial instance so lit states are independent.
	var mat := ShaderMaterial.new()
	mat.shader = load(_SHADER_PATH)
	mat.set_shader_parameter("lit",       0.0)
	mat.set_shader_parameter("win_pulse", 0.0)

	var rect := ColorRect.new()
	rect.position       = pos
	rect.size           = Vector2(_cell_size, _cell_size)
	rect.color          = Color.WHITE  # shader drives final color; host color unused
	rect.material       = mat
	rect.mouse_filter   = Control.MOUSE_FILTER_IGNORE  # don't intercept board clicks
	add_child(rect)

	_targets[cell] = {"rect": rect, "mat": mat}
