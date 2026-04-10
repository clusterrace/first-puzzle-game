# Game.gd — Sight Lines production game scene (KAMA-23).
# Loads level data from JSON files via LevelManager, renders the grid
# using _draw(), handles player input, and integrates with SaveManager.
#
# S4 rendering layer (KAMA-20): RayRenderer and TargetRenderer subscribe to
# the signals emitted here.
#
# Coordinate convention: (row, col) — row increases downward, col increases
# rightward. Matches LevelData.tile_grid and GridEnums.DIRECTION_DELTA.
extends Node2D

# ── S4 rendering signals (KAMA-20) ──────────────────────────────────────────
## Emitted at level load; provides target cells for TargetRenderer.
signal level_loaded(target_cells: Array)
## Emitted after every ray recalculation with the full segment list.
signal rays_changed(segments: Array)
## Emitted once per target when its lit state changes.
signal target_state_changed(cell: Vector2i, is_lit: bool)
## Emitted once when all targets become simultaneously lit.
signal win_achieved()

# ── Grid geometry ────────────────────────────────────────────────────────────
## Pixel side-length of one grid cell. Fixed throughout the game.
const CELL: int = 80
## Grid dimensions — updated each time load_level() is called.
var ROWS: int = 0
var COLS: int = 0
## Screen-space top-left corner of the grid. Recentred on every load.
var PAD_X: float = 40.0
var PAD_Y: float = 50.0

# ── Internal cell-type constants (Game.gd rendering layer only) ──────────────
# These are NOT GridEnums values. They are used internally for the grid array
# and drive _draw() and _trace_ray(). Convert from LevelData via helpers below.
const EMPTY      = 0
const WALL       = 1
const OBS        = 2   # observer piece — emits a sight ray
const MIR_F      = 3   # / mirror (MIRROR_FWDSLASH)
const MIR_B      = 4   # \ mirror (MIRROR_BKSLASH)
const TGT        = 5   # target tile — must be lit to win
const SLOT       = 6   # empty placeable slot
const AVOID_TGT  = 7   # must-NOT-light target (E10) — win blocked when lit

# ── Direction constants (Game.gd rendering layer only) ───────────────────────
# RT=right, DN=down, LT=left, UP=up.
# Maps to GridEnums: RT↔EAST, DN↔SOUTH, LT↔WEST, UP↔NORTH.
const RT = 0
const DN = 1
const LT = 2
const UP = 3
# Direction deltas: [right, down, left, up] — (x = col delta, y = row delta).
const DIR_V: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)
]

# ── Colours ───────────────────────────────────────────────────────────────────
const C_BG      := Color(0.08, 0.09, 0.12)
const C_WALL    := Color(0.22, 0.23, 0.27)
const C_DARK    := Color(0.11, 0.13, 0.17)
const C_OBS     := Color(0.38, 0.70, 1.00)
const C_MIR     := Color(0.80, 0.84, 0.96)
const C_RAY     := Color(0.42, 0.84, 1.00, 0.80)
const C_HOVER   := Color(1.00, 1.00, 1.00, 0.13)
const C_UI      := Color(0.58, 0.60, 0.70)
const C_WIN     := Color(0.22, 1.00, 0.45)
const C_TITLE   := Color(0.70, 0.72, 0.82)

# ── Mutable game state ────────────────────────────────────────────────────────
var level_idx:    int        = 0
var grid:         Array      = []       # Array[Array[int]] — cell type per tile
var obs_dirs:     Dictionary = {}       # Vector2i(row,col) → int (RT/DN/LT/UP)
var hand:         Array      = []       # remaining pieces (Game.gd constants)
var lit:          Dictionary = {}       # Vector2i(row,col) → bool
var ray_segs:     Array      = []       # Array[{from:Vector2, to:Vector2}]
var hover_cell:   Vector2i   = Vector2i(-1, -1)
var win:          bool       = false
var _level_title: String     = ""
var font:         Font

# ── Undo / Reset (KAMA-24 fix) ───────────────────────────────────────────────
var _undo_stack:       Array      = []   # stack of {grid, obs_dirs, hand} snapshots
var _initial_grid:     Array      = []   # level-load snapshot for Reset
var _initial_obs_dirs: Dictionary = {}
var _initial_hand:     Array      = []

# ── S4 renderer references (KAMA-20) ─────────────────────────────────────────
var _ray_renderer:    Node2D
var _target_renderer: Node2D

# ── Pause menu (KAMA-31) ──────────────────────────────────────────────────────
var _pause_canvas:  CanvasLayer
var _pause_overlay: Node2D


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	font = ThemeDB.fallback_font
	_setup_renderers()
	_setup_pause_menu()
	load_level(LevelManager.current_index)


func _setup_renderers() -> void:
	_target_renderer = load("res://scripts/TargetRenderer.gd").new()
	_target_renderer.setup(PAD_X, PAD_Y, CELL)
	add_child(_target_renderer)

	_ray_renderer = load("res://scripts/RayRenderer.gd").new()
	add_child(_ray_renderer)


func _setup_pause_menu() -> void:
	_pause_canvas = CanvasLayer.new()
	_pause_canvas.layer = 64
	_pause_canvas.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(_pause_canvas)

	_pause_overlay = load("res://scripts/PauseMenuOverlay.gd").new()
	_pause_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_pause_overlay.visible = false
	_pause_canvas.add_child(_pause_overlay)

	_pause_overlay.resume_requested.connect(_on_pause_resume)
	_pause_overlay.restart_requested.connect(_on_pause_restart)
	_pause_overlay.quit_menu_requested.connect(_on_pause_quit_menu)


# ── Level loading ─────────────────────────────────────────────────────────────

func load_level(idx: int) -> void:
	var data: LevelData = LevelManager.load_level_data(idx)
	if data == null:
		push_error("Game.load_level: failed to load level index %d" % idx)
		return

	level_idx    = idx
	ROWS         = data.rows
	COLS         = data.cols
	_level_title = data.title

	# Centre the grid in the 760×580 viewport, reserving vertical space for HUD.
	PAD_X = (760.0 - COLS * CELL) / 2.0
	PAD_Y = maxf((580.0 - ROWS * CELL) / 2.0 - 20.0, 40.0)

	# Build the 2D grid from LevelData's flat tile array.
	grid = []
	for r: int in range(ROWS):
		var row: Array = []
		for c: int in range(COLS):
			row.append(_tile_to_game(data.tile_grid[r * COLS + c]))
		grid.append(row)

	# Apply fixed (pre-placed) pieces on top of their slot tiles.
	obs_dirs = {}
	for fp: Dictionary in data.fixed_pieces:
		var r: int = fp["row"]
		var c: int = fp["col"]
		var piece: int = _piece_to_game(fp["piece_type"])
		grid[r][c] = piece
		if piece == OBS:
			obs_dirs[Vector2i(r, c)] = _dir_to_game(fp["direction"])

	# Build the player's piece hand from the inventory list.
	hand = []
	for pt_int: int in data.player_inventory:
		hand.append(_piece_to_game(pt_int))

	lit        = {}
	ray_segs   = []
	win        = false
	hover_cell = Vector2i(-1, -1)

	# Snapshot initial state for Undo/Reset.
	_undo_stack       = []
	_initial_grid     = _deep_copy_grid(grid)
	_initial_obs_dirs = obs_dirs.duplicate(true)
	_initial_hand     = hand.duplicate()

	# Collect target positions for S4 renderers.
	var target_cells: Array[Vector2i] = []
	var avoid_cells:  Array[Vector2i] = []
	for r: int in range(ROWS):
		for c: int in range(COLS):
			if grid[r][c] == TGT:
				target_cells.append(Vector2i(r, c))
			elif grid[r][c] == AVOID_TGT:
				avoid_cells.append(Vector2i(r, c))

	if _ray_renderer:
		_ray_renderer.clear()
	if _target_renderer:
		# Re-run setup so new PAD_X/PAD_Y take effect before building nodes.
		_target_renderer.setup(PAD_X, PAD_Y, CELL)
		_target_renderer.set_targets(target_cells)
		_target_renderer.set_avoid_targets(avoid_cells)

	level_loaded.emit(target_cells)
	_update_rays()
	queue_redraw()


# ── LevelData → Game.gd conversion helpers ───────────────────────────────────

## TileType (KAMA-11): EMPTY=0, WALL=1, SLOT=2, TARGET=3, TARGET_AVOID=4
func _tile_to_game(tile: int) -> int:
	match tile:
		0: return EMPTY
		1: return WALL
		2: return SLOT
		3: return TGT
		4: return AVOID_TGT
		_: return EMPTY


## PieceType (KAMA-11): OBSERVER=1, MIRROR_FWDSLASH=2, MIRROR_BKSLASH=3
func _piece_to_game(piece: int) -> int:
	match piece:
		1: return OBS
		2: return MIR_F
		3: return MIR_B
		_: return EMPTY


## Direction (KAMA-11): NORTH=0, EAST=1, SOUTH=2, WEST=3
## Game.gd:             UP=3,   RT=0,   DN=1,   LT=2
func _dir_to_game(dir: int) -> int:
	match dir:
		0: return UP
		1: return RT
		2: return DN
		3: return LT
		_: return RT


# ── Helpers ───────────────────────────────────────────────────────────────────

func cell_center(r: int, c: int) -> Vector2:
	return Vector2(PAD_X + c * CELL + CELL * 0.5, PAD_Y + r * CELL + CELL * 0.5)


func screen_to_cell(pos: Vector2) -> Vector2i:
	var lx := pos.x - PAD_X
	var ly := pos.y - PAD_Y
	return Vector2i(int(ly / CELL), int(lx / CELL))


func in_bounds(r: int, c: int) -> bool:
	return r >= 0 and r < ROWS and c >= 0 and c < COLS


# ── Ray tracing ───────────────────────────────────────────────────────────────

func _update_rays() -> void:
	ray_segs = []
	var previously_lit: Dictionary = lit.duplicate()

	# Reset all target lit states (both regular and avoid).
	lit = {}
	for r: int in range(ROWS):
		for c: int in range(COLS):
			if grid[r][c] == TGT or grid[r][c] == AVOID_TGT:
				lit[Vector2i(r, c)] = false

	# Trace a ray from every observer on the grid.
	for cell: Vector2i in obs_dirs.keys():
		if in_bounds(cell.x, cell.y) and grid[cell.x][cell.y] == OBS:
			_trace_ray(cell.x, cell.y, obs_dirs[cell])

	# Detect newly lit regular targets for audio events (avoid targets excluded).
	var newly_lit: Array[Vector2i] = []
	for target_pos: Vector2i in lit.keys():
		if grid[target_pos.x][target_pos.y] == TGT \
				and lit[target_pos] and not previously_lit.get(target_pos, false):
			newly_lit.append(target_pos)

	# Win condition: at least one regular target exists, all regular targets lit,
	# and no avoid target has been hit (E10).
	var has_regular: bool = false
	var all_regular_lit: bool = true
	var all_avoid_unlit: bool = true
	for cell: Vector2i in lit.keys():
		var cell_type: int = grid[cell.x][cell.y]
		if cell_type == TGT:
			has_regular = true
			if not lit[cell]:
				all_regular_lit = false
		elif cell_type == AVOID_TGT:
			if lit[cell]:
				all_avoid_unlit = false
	var all_lit: bool = has_regular and all_regular_lit and all_avoid_unlit

	if all_lit and not win:
		AudioManager.evt_level_complete()
		SaveManager.mark_level_complete(LevelManager.get_level_id(level_idx))

	for i: int in range(newly_lit.size()):
		AudioManager.evt_target_lit(i)

	var was_win := win
	win = all_lit

	if _ray_renderer:
		_ray_renderer.refresh(ray_segs)
	rays_changed.emit(ray_segs)

	for cell: Vector2i in lit.keys():
		var is_lit: bool = lit[cell]
		if _target_renderer:
			_target_renderer.set_lit(cell, is_lit)
		target_state_changed.emit(cell, is_lit)

	if all_lit and not was_win:
		if _target_renderer:
			_target_renderer.set_win_pulse(true)
		win_achieved.emit()

	queue_redraw()


func _trace_ray(sr: int, sc: int, dir: int) -> void:
	var r := sr
	var c := sc
	var d := dir
	var prev := cell_center(r, c)

	# Bound: at most ROWS*COLS*4 steps to prevent any infinite loop edge case.
	for _step: int in range(ROWS * COLS * 4):
		var dv: Vector2i = DIR_V[d]
		var nr := r + dv.y   # row delta is in dv.y
		var nc := c + dv.x   # col delta is in dv.x

		if not in_bounds(nr, nc):
			# Draw to the midpoint of the out-of-bounds cell then stop.
			var next := cell_center(nr, nc)
			ray_segs.append({"from": prev, "to": prev.lerp(next, 0.5)})
			break

		var cur := cell_center(nr, nc)
		var t: int = grid[nr][nc]

		if t == WALL:
			ray_segs.append({"from": prev, "to": prev.lerp(cur, 0.5)})
			break
		elif t == TGT or t == AVOID_TGT:
			ray_segs.append({"from": prev, "to": cur})
			lit[Vector2i(nr, nc)] = true
			# Ray passes THROUGH all target tiles (spec §3.2, E10).
			# AVOID_TGT being lit blocks the win condition.
			r = nr; c = nc; prev = cur
		elif t == MIR_F or t == MIR_B:
			ray_segs.append({"from": prev, "to": cur})
			d = _reflect(d, t == MIR_F)
			r = nr; c = nc; prev = cur
		else:
			# EMPTY, SLOT, OBS: pass through.
			ray_segs.append({"from": prev, "to": cur})
			r = nr; c = nc; prev = cur


func _reflect(d: int, is_fwd: bool) -> int:
	# /  mirror: RT→UP, DN→LT, LT→DN, UP→RT
	# \  mirror: RT→DN, DN→RT, LT→UP, UP→LT
	if is_fwd:
		match d:
			RT: return UP
			DN: return LT
			LT: return DN
			UP: return RT
	else:
		match d:
			RT: return DN
			DN: return RT
			LT: return UP
			UP: return LT
	return d


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# ESC → open pause menu (KAMA-31).
	if event is InputEventKey and event.pressed \
			and event.keycode == KEY_ESCAPE:
		_open_pause_menu()
		return

	# Z → undo last action.  R → reset to level-load state.
	if event is InputEventKey and event.pressed and not win:
		if event.keycode == KEY_Z:
			if _undo_stack.size() > 0:
				_restore_snapshot(_undo_stack.pop_back())
			return
		if event.keycode == KEY_R:
			_undo_stack = []
			_restore_snapshot({
				"grid":     _initial_grid,
				"obs_dirs": _initial_obs_dirs,
				"hand":     _initial_hand,
			})
			return

	if win:
		if event is InputEventMouseButton and event.pressed:
			if LevelManager.is_last_level(level_idx):
				await AudioManager.evt_advance_level()
				get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
			else:
				var next: int = level_idx + 1
				await AudioManager.evt_advance_level()
				LevelManager.current_index = next
				load_level(next)
		return

	if event is InputEventMouseMotion:
		var cell := screen_to_cell(event.position)
		if cell != hover_cell:
			hover_cell = cell
			queue_redraw()

	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := screen_to_cell(event.position)
		if not in_bounds(cell.x, cell.y):
			return
		var r := cell.x
		var c := cell.y
		var t: int = grid[r][c]

		if t == SLOT and hand.size() > 0:
			_push_undo_snapshot()
			var piece: int = hand[0]
			hand.remove_at(0)
			grid[r][c] = piece
			if piece == OBS:
				obs_dirs[Vector2i(r, c)] = RT
			AudioManager.evt_piece_placed()
			_update_rays()
		elif t == OBS and obs_dirs.has(Vector2i(r, c)):
			# Rotate placed observer CW: RT→DN→LT→UP→RT
			_push_undo_snapshot()
			obs_dirs[Vector2i(r, c)] = (obs_dirs[Vector2i(r, c)] + 1) % 4
			AudioManager.evt_mirror_flipped()
			_update_rays()
		elif t == MIR_F:
			_push_undo_snapshot()
			grid[r][c] = MIR_B
			AudioManager.evt_mirror_flipped()
			_update_rays()
		elif t == MIR_B:
			_push_undo_snapshot()
			grid[r][c] = MIR_F
			AudioManager.evt_mirror_flipped()
			_update_rays()


# ── Undo / Reset helpers ─────────────────────────────────────────────────────

func _deep_copy_grid(src: Array) -> Array:
	var result: Array = []
	for row in src:
		result.append(row.duplicate())
	return result


func _push_undo_snapshot() -> void:
	_undo_stack.append({
		"grid":     _deep_copy_grid(grid),
		"obs_dirs": obs_dirs.duplicate(true),
		"hand":     hand.duplicate(),
	})


func _restore_snapshot(snap: Dictionary) -> void:
	grid     = _deep_copy_grid(snap["grid"])
	obs_dirs = snap["obs_dirs"].duplicate(true)
	hand     = snap["hand"].duplicate()
	win      = false
	_update_rays()
	queue_redraw()


# ── Pause menu handlers (KAMA-31) ─────────────────────────────────────────────

func _open_pause_menu() -> void:
	_pause_overlay.visible = true
	get_tree().paused = true


func _on_pause_resume() -> void:
	get_tree().paused = false
	_pause_overlay.visible = false


func _on_pause_restart() -> void:
	get_tree().paused = false
	_pause_overlay.visible = false
	load_level(level_idx)


func _on_pause_quit_menu() -> void:
	get_tree().paused = false
	_pause_overlay.visible = false
	SceneTransition.change_scene("res://scenes/MainMenu.tscn")


# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	draw_rect(Rect2(0, 0, 760, 580), C_BG)

	for r: int in range(ROWS):
		for c: int in range(COLS):
			var rect := Rect2(PAD_X + c * CELL, PAD_Y + r * CELL, CELL, CELL)
			var t: int = grid[r][c]
			var pos  := Vector2i(r, c)

			match t:
				WALL: draw_rect(rect, C_WALL)
				_:    draw_rect(rect, C_DARK)

			match t:
				SLOT:  _draw_slot_border(rect)
				OBS:   _draw_observer(rect, obs_dirs.get(pos, RT))
				MIR_F: _draw_mirror(rect, true)
				MIR_B: _draw_mirror(rect, false)
				# TGT: handled by TargetRenderer shader node (KAMA-20)

			if pos == hover_cell and t == SLOT and hand.size() > 0:
				draw_rect(rect, C_HOVER)

	# Rays: handled by RayRenderer shader node (KAMA-20)

	# Grid lines
	for r: int in range(ROWS + 1):
		draw_line(
			Vector2(PAD_X,               PAD_Y + r * CELL),
			Vector2(PAD_X + COLS * CELL, PAD_Y + r * CELL),
			Color(0, 0, 0, 0.25), 1
		)
	for c: int in range(COLS + 1):
		draw_line(
			Vector2(PAD_X + c * CELL, PAD_Y),
			Vector2(PAD_X + c * CELL, PAD_Y + ROWS * CELL),
			Color(0, 0, 0, 0.25), 1
		)

	_draw_hud()

	if win:
		_draw_win_overlay()


func _draw_slot_border(rect: Rect2) -> void:
	var steps := 5
	var col   := Color(0.28, 0.32, 0.40, 0.8)
	var corners := [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	for i: int in range(4):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		for s: int in range(steps):
			if s % 2 == 0:
				var t0 := float(s)     / steps
				var t1 := float(s + 1) / steps
				draw_line(a.lerp(b, t0), a.lerp(b, t1), col, 1.5)


func _draw_observer(rect: Rect2, dir: int) -> void:
	var cx := rect.position.x + CELL * 0.5
	var cy := rect.position.y + CELL * 0.5
	var r  := CELL * 0.26

	draw_circle(Vector2(cx, cy), r,        C_OBS)
	draw_circle(Vector2(cx, cy), r * 0.44, C_BG)

	var dv: Vector2i = DIR_V[dir]
	var tip := Vector2(cx + dv.x * r * 1.6, cy + dv.y * r * 1.6)
	draw_line(Vector2(cx, cy), tip, C_OBS, 3.0, true)
	draw_circle(tip, 3.5, C_OBS)


func _draw_mirror(rect: Rect2, is_fwd: bool) -> void:
	var m := CELL * 0.16
	var p := rect.position
	var e := rect.end
	if is_fwd:
		draw_line(Vector2(e.x - m, p.y + m), Vector2(p.x + m, e.y - m), C_MIR, 4.0, true)
	else:
		draw_line(Vector2(p.x + m, p.y + m), Vector2(e.x - m, e.y - m), C_MIR, 4.0, true)


func _draw_hud() -> void:
	# Level title above the grid.
	draw_string(font, Vector2(PAD_X, PAD_Y - 16.0), _level_title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_TITLE)

	# Hand panel to the right of the grid.
	var hx := PAD_X + COLS * CELL + 18.0
	var hy := PAD_Y + 8.0

	if hand.size() > 0:
		draw_string(font, Vector2(hx, hy + 14), "Place:",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_UI)
		var pw := CELL * 0.72
		for i: int in range(hand.size()):
			var piece: int = hand[i]
			var py    := hy + 24.0 + i * (pw + 10.0)
			var prect := Rect2(hx, py, pw, pw)
			draw_rect(prect, C_DARK)
			_draw_slot_border(prect)
			match piece:
				OBS:   _draw_observer(prect, RT)
				MIR_F: _draw_mirror(prect, true)
				MIR_B: _draw_mirror(prect, false)
		if _grid_has_placed_mirror():
			draw_string(font,
				Vector2(hx, hy + 24.0 + hand.size() * (pw + 10.0) + 16.0),
				"click placed\nmirror to flip",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.48, 0.50, 0.60))
	else:
		draw_string(font, Vector2(hx, hy + 14), "All placed",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.48, 0.72, 0.48))

	# Level counter bottom-right.
	var level_count: int = LevelManager.get_level_count()
	var level_id: String = LevelManager.get_level_id(level_idx)
	var counter    := "%d / %d" % [level_idx + 1, level_count]
	var done_mark  := " \u2713" if SaveManager.is_level_complete(level_id) else ""
	draw_string(font, Vector2(700.0, 558.0), counter + done_mark,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_UI)

	# Keyboard hints bottom-left.
	var hint_col := Color(0.38, 0.40, 0.50)
	draw_string(font, Vector2(PAD_X, 549.0), "Z \u2014 undo   R \u2014 reset",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, hint_col)
	draw_string(font, Vector2(PAD_X, 562.0), "ESC \u2014 pause",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, hint_col)


func _grid_has_placed_mirror() -> bool:
	for r: int in range(ROWS):
		for c: int in range(COLS):
			if grid[r][c] == MIR_F or grid[r][c] == MIR_B:
				return true
	return false


func _draw_win_overlay() -> void:
	draw_rect(Rect2(0, 0, 760, 580), Color(0, 0, 0, 0.52))

	var cx := 380.0
	var cy := 250.0
	draw_rect(Rect2(cx - 170, cy - 60, 340, 140), Color(0.08, 0.11, 0.14, 0.95))

	draw_string(font, Vector2(cx - 140, cy - 24), "All targets illuminated",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, C_WIN)

	var sub: String
	if LevelManager.is_last_level(level_idx):
		sub = "Click to return to level select"
	else:
		sub = "Click to continue"
	draw_string(font, Vector2(cx - 140, cy + 18), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_UI)
