class_name GridAffordanceRenderer
extends Node2D
## S3: Grid-level visual affordances for player interaction feedback (KAMA-19).
##
## Renders all "show don't tell" feedback that communicates legality and
## interactivity without text:
##   - Hover highlight: valid SLOT (white) vs invalid cell (red tint) when
##     carrying a piece (PIECE_SELECTED state).
##   - Ghost piece preview at the hover cell when a placement would succeed.
##   - Rejection flash: brief red overlay on the hover cell when a placement
##     attempt fails (triggered by InputController.placement_rejected signal).
##   - Idle affordance: subtle highlight + indicator icons on interactable
##     pieces when hovering in IDLE state (no piece selected):
##       * Observer → circular rotation arrow (indicates CW rotate on click)
##       * Mirror   → ↔ toggle arrows (indicates orientation flip on click)
##   - Cursor shape: ARROW / POINTING_HAND / CAN_DROP / FORBIDDEN driven by
##     state and hover cell.
##
## Zero game logic. Subscribes to InputController signals and reads GridState.
##
## Setup:
##   var aff := GridAffordanceRenderer.new()
##   add_child(aff)
##   aff.setup(grid_state, input_controller, pad_x, pad_y, cell_size)
##
## Config file: "res://config/affordance_renderer.json"
## Keys: hover_valid_color, hover_invalid_color, ghost_alpha, reject_color,
##       reject_duration_sec, affordance_color  (see _load_config for formats).
##
## Coordinate convention: Vector2i(row, col) — pos.x = row, pos.y = col.
## Screen positions: x = horizontal (col-based), y = vertical (row-based).

const _CONFIG_PATH := "res://config/affordance_renderer.json"

# Piece drawing colours — match Game.gd palette so ghost previews look native.
const _C_OBS := Color(0.38, 0.70, 1.00)
const _C_MIR := Color(0.80, 0.84, 0.96)
const _C_BG  := Color(0.08, 0.09, 0.12)

# Screen-space direction unit vectors indexed by GridEnums.Direction.
# Derived from DIRECTION_DELTA: screen_x = col delta (.y), screen_y = row delta (.x).
const _SCREEN_DIR: Array[Vector2] = [
	Vector2( 0, -1),  # NORTH — row decreases → screen y decreases (up)
	Vector2( 1,  0),  # EAST  — col increases  → screen x increases (right)
	Vector2( 0,  1),  # SOUTH — row increases  → screen y increases (down)
	Vector2(-1,  0),  # WEST  — col decreases  → screen x decreases (left)
]


# ── Bound systems ─────────────────────────────────────────────────────────────

var _grid: GridState       = null
var _input_ctrl: InputController = null


# ── Grid geometry ─────────────────────────────────────────────────────────────

var _pad_x: float = 40.0
var _pad_y: float = 50.0
var _cell_size: int = 80


# ── Mirrored interaction state ────────────────────────────────────────────────

var _state: InputController.State = InputController.State.IDLE
var _selected_piece_type: int     = -1
var _default_direction: GridEnums.Direction = GridEnums.Direction.EAST
var _hover_cell: Vector2i         = Vector2i(-1, -1)


# ── Rejection flash ───────────────────────────────────────────────────────────

var _reject_remaining: float = 0.0


# ── Config (loaded from file, designers tune these) ───────────────────────────

## Overlay colour on a valid SLOT cell when carrying a piece.
var _hover_valid_color: Color   = Color(1.00, 1.00, 1.00, 0.13)
## Overlay colour on an invalid cell (non-SLOT or occupied) when carrying a piece.
var _hover_invalid_color: Color = Color(1.00, 0.30, 0.30, 0.08)
## Alpha for the ghost piece preview drawn at the valid hover cell.
var _ghost_alpha: float         = 0.40
## Peak colour of the rejection flash overlay.
var _reject_color: Color        = Color(1.00, 0.15, 0.15, 0.55)
## Seconds the rejection flash lasts (fades linearly to transparent).
var _reject_duration: float     = 0.22
## Colour for idle-state interactability indicators (rotation/toggle arrows).
var _affordance_color: Color    = Color(1.00, 1.00, 1.00, 0.28)


# ── Setup ─────────────────────────────────────────────────────────────────────

## Bind the renderer to the grid and input systems and load config.
## Call once after the level is loaded and InputController is set up.
func setup(
		grid: GridState,
		input_ctrl: InputController,
		pad_x: float,
		pad_y: float,
		cell_size: int) -> void:
	_grid             = grid
	_input_ctrl       = input_ctrl
	_pad_x            = pad_x
	_pad_y            = pad_y
	_cell_size        = cell_size
	_default_direction = input_ctrl.get_default_direction()

	_load_config()

	# Mirror current controller state (handles late binding after signals fire).
	_state = input_ctrl.get_state()
	_hover_cell = input_ctrl.get_hover_cell()

	input_ctrl.piece_type_selected.connect(_on_piece_type_selected)
	input_ctrl.piece_deselected.connect(_on_piece_deselected)
	input_ctrl.placement_rejected.connect(_on_placement_rejected)
	input_ctrl.action_performed.connect(_on_action_performed)
	input_ctrl.input_locked.connect(_on_input_locked)
	input_ctrl.hover_cell_changed.connect(_on_hover_cell_changed)

	queue_redraw()


# ── Godot callbacks ───────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _reject_remaining > 0.0:
		_reject_remaining = maxf(0.0, _reject_remaining - delta)
		queue_redraw()


func _draw() -> void:
	if _grid == null:
		return
	_draw_hover_affordance()
	_draw_reject_flash()


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_piece_type_selected(piece_type: int) -> void:
	_state = InputController.State.PIECE_SELECTED
	_selected_piece_type = piece_type
	_update_cursor()
	queue_redraw()


func _on_piece_deselected() -> void:
	_state = InputController.State.IDLE
	_selected_piece_type = -1
	_update_cursor()
	queue_redraw()


func _on_placement_rejected() -> void:
	_reject_remaining = _reject_duration
	queue_redraw()


func _on_action_performed() -> void:
	# Grid state changed — redraw affordances so idle indicators stay accurate.
	queue_redraw()


func _on_input_locked() -> void:
	_state = InputController.State.LOCKED
	_selected_piece_type = -1
	_update_cursor()
	queue_redraw()


func _on_hover_cell_changed(cell: Vector2i) -> void:
	_hover_cell = cell
	_update_cursor()
	queue_redraw()


# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw_hover_affordance() -> void:
	if not _grid.is_in_bounds(_hover_cell):
		return

	match _state:
		InputController.State.PIECE_SELECTED:
			_draw_piece_selected_hover()
		InputController.State.IDLE:
			_draw_idle_hover()
		# LOCKED: no affordances drawn.


func _draw_piece_selected_hover() -> void:
	var rect := _cell_rect(_hover_cell)
	if _grid.is_placeable(_hover_cell):
		draw_rect(rect, _hover_valid_color)
		_draw_ghost_piece(rect, _selected_piece_type, _default_direction)
	else:
		draw_rect(rect, _hover_invalid_color)


func _draw_idle_hover() -> void:
	var piece_type := _grid.get_piece_type(_hover_cell)
	if piece_type == GridEnums.PieceType.NONE:
		return
	if _grid.is_piece_fixed(_hover_cell):
		return  # Fixed pieces cannot be interacted with.

	var rect := _cell_rect(_hover_cell)
	# Subtle background highlight to show this piece is clickable.
	draw_rect(rect, _affordance_color)

	match piece_type:
		GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.PieceType.MIRROR_BKSLASH:
			_draw_toggle_arrows(rect)
		GridEnums.PieceType.OBSERVER:
			_draw_rotation_arc(rect)


func _draw_reject_flash() -> void:
	if _reject_remaining <= 0.0:
		return
	if not _grid.is_in_bounds(_hover_cell):
		return
	# Fade out linearly: full colour at t=1.0, fully transparent at t=0.0.
	var t := _reject_remaining / _reject_duration
	var col := Color(_reject_color.r, _reject_color.g, _reject_color.b, _reject_color.a * t)
	draw_rect(_cell_rect(_hover_cell), col)


# ── Ghost piece preview ───────────────────────────────────────────────────────

## Draw a translucent preview of [param piece_type] facing [param dir] inside [param rect].
func _draw_ghost_piece(rect: Rect2, piece_type: int, dir: GridEnums.Direction) -> void:
	var obs_col := Color(_C_OBS.r, _C_OBS.g, _C_OBS.b, _ghost_alpha)
	var mir_col := Color(_C_MIR.r, _C_MIR.g, _C_MIR.b, _ghost_alpha)
	var bg_col  := Color(_C_BG.r,  _C_BG.g,  _C_BG.b,  _ghost_alpha)

	match piece_type:
		GridEnums.PieceType.OBSERVER:
			_draw_observer_icon(rect, dir, obs_col, bg_col)
		GridEnums.PieceType.MIRROR_FWDSLASH:
			_draw_mirror_icon(rect, true,  mir_col)
		GridEnums.PieceType.MIRROR_BKSLASH:
			_draw_mirror_icon(rect, false, mir_col)


# ── Piece icon helpers ────────────────────────────────────────────────────────

## Draw an observer circle with a directional pointer.
## [param dir] uses GridEnums.Direction; converted to screen space via _SCREEN_DIR.
func _draw_observer_icon(
		rect: Rect2,
		dir: GridEnums.Direction,
		col: Color,
		bg: Color) -> void:
	var cx := rect.position.x + _cell_size * 0.5
	var cy := rect.position.y + _cell_size * 0.5
	var r  := _cell_size * 0.26

	draw_circle(Vector2(cx, cy), r,        col)
	draw_circle(Vector2(cx, cy), r * 0.44, bg)

	var dv: Vector2 = _SCREEN_DIR[dir]
	var tip := Vector2(cx + dv.x * r * 1.6, cy + dv.y * r * 1.6)
	draw_line(Vector2(cx, cy), tip, col, 3.0, true)
	draw_circle(tip, 3.5, col)


## Draw a mirror line (/ or \) inside [param rect].
func _draw_mirror_icon(rect: Rect2, is_fwd: bool, col: Color) -> void:
	var m := _cell_size * 0.16
	var p := rect.position
	var e := rect.end
	if is_fwd:
		draw_line(Vector2(e.x - m, p.y + m), Vector2(p.x + m, e.y - m), col, 4.0, true)
	else:
		draw_line(Vector2(p.x + m, p.y + m), Vector2(e.x - m, e.y - m), col, 4.0, true)


# ── Idle affordance indicators ────────────────────────────────────────────────

## Draw a ↔ double-headed arrow to indicate a mirror can be toggled.
func _draw_toggle_arrows(rect: Rect2) -> void:
	var cx  := rect.position.x + _cell_size * 0.5
	var cy  := rect.position.y + _cell_size * 0.5
	var aw  := _cell_size * 0.20   # half-length of the central shaft
	var ah  := _cell_size * 0.09   # arrowhead arm length
	var col := _affordance_color

	# Horizontal shaft.
	draw_line(Vector2(cx - aw, cy), Vector2(cx + aw, cy), col, 1.5, true)
	# Left arrowhead (pointing left).
	draw_line(Vector2(cx - aw, cy), Vector2(cx - aw + ah, cy - ah), col, 1.5, true)
	draw_line(Vector2(cx - aw, cy), Vector2(cx - aw + ah, cy + ah), col, 1.5, true)
	# Right arrowhead (pointing right).
	draw_line(Vector2(cx + aw, cy), Vector2(cx + aw - ah, cy - ah), col, 1.5, true)
	draw_line(Vector2(cx + aw, cy), Vector2(cx + aw - ah, cy + ah), col, 1.5, true)


## Draw a CW circular arc with an arrowhead to indicate an observer can be rotated.
func _draw_rotation_arc(rect: Rect2) -> void:
	var cx       := rect.position.x + _cell_size * 0.5
	var cy       := rect.position.y + _cell_size * 0.5
	var radius   := _cell_size * 0.30
	var col      := _affordance_color
	var segments := 10

	# Arc spans ~270° starting from the top (−90°) going clockwise.
	var start_a  := -TAU * 0.25          # −90° (12 o'clock)
	var sweep    :=  TAU * 0.75          # 270° CW sweep

	var prev := Vector2(
		cx + radius * cos(start_a),
		cy + radius * sin(start_a))
	for i in range(1, segments + 1):
		var t     := float(i) / float(segments)
		var angle := start_a + sweep * t
		var cur   := Vector2(cx + radius * cos(angle), cy + radius * sin(angle))
		draw_line(prev, cur, col, 1.5, true)
		prev = cur

	# Arrowhead tangent to the arc at the end point (pointing clockwise).
	var end_angle  := start_a + sweep
	var tangent    := Vector2(-sin(end_angle), cos(end_angle))  # CW tangent
	var ah         := _cell_size * 0.08
	draw_line(prev, prev - tangent.rotated(deg_to_rad( 35.0)) * ah, col, 1.5, true)
	draw_line(prev, prev - tangent.rotated(deg_to_rad(-35.0)) * ah, col, 1.5, true)


# ── Cursor management ─────────────────────────────────────────────────────────

## Update the OS cursor shape to reflect current interaction context.
## Called on every state or hover change.
func _update_cursor() -> void:
	DisplayServer.cursor_set_shape(_compute_cursor_shape())


## Compute the appropriate cursor shape without applying it.
## Extracted so tests can verify cursor logic without a display.
func _compute_cursor_shape() -> DisplayServer.CursorShape:
	if _state == InputController.State.LOCKED:
		return DisplayServer.CURSOR_ARROW

	if not (_grid != null and _grid.is_in_bounds(_hover_cell)):
		return DisplayServer.CURSOR_ARROW

	match _state:
		InputController.State.IDLE:
			var piece := _grid.get_piece_type(_hover_cell)
			if piece != GridEnums.PieceType.NONE and not _grid.is_piece_fixed(_hover_cell):
				return DisplayServer.CURSOR_POINTING_HAND
			return DisplayServer.CURSOR_ARROW

		InputController.State.PIECE_SELECTED:
			if _grid.is_placeable(_hover_cell):
				return DisplayServer.CURSOR_CAN_DROP
			return DisplayServer.CURSOR_FORBIDDEN

	return DisplayServer.CURSOR_ARROW


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns the screen-space Rect2 for the given grid cell.
func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		_pad_x + cell.y * _cell_size,
		_pad_y + cell.x * _cell_size,
		_cell_size,
		_cell_size)


# ── Config loading ────────────────────────────────────────────────────────────

## Load visual configuration from the JSON config file.
## Silently uses hardcoded defaults when the file is missing or malformed.
## Colors are stored as [r, g, b, a] arrays (values 0.0–1.0).
func _load_config() -> void:
	var file := FileAccess.open(_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var raw := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_warning("GridAffordanceRenderer: config at '%s' is not valid JSON; using defaults." % _CONFIG_PATH)
		return

	var cfg: Dictionary = parsed as Dictionary
	_hover_valid_color   = _read_color(cfg, "hover_valid_color",   _hover_valid_color)
	_hover_invalid_color = _read_color(cfg, "hover_invalid_color", _hover_invalid_color)
	_ghost_alpha         = float(cfg.get("ghost_alpha",             _ghost_alpha))
	_reject_color        = _read_color(cfg, "reject_color",         _reject_color)
	_reject_duration     = float(cfg.get("reject_duration_sec",     _reject_duration))
	_affordance_color    = _read_color(cfg, "affordance_color",     _affordance_color)


## Parse a [r, g, b, a] Array from [param cfg] at [param key].
## Returns [param fallback] when the key is missing or malformed.
static func _read_color(cfg: Dictionary, key: String, fallback: Color) -> Color:
	var v: Variant = cfg.get(key, null)
	if v is Array and v.size() == 4:
		return Color(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	return fallback
