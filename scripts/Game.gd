# Game.gd — Sight Lines Prototype
# Hypothesis: grid-based sight-line placement is intuitive and satisfying without text.
# Throwaway quality — do not carry into production.
extends Node2D

# ── Grid constants ────────────────────────────────────────────────────────────
const CELL  = 80
const ROWS  = 6
const COLS  = 7
const PAD_X = 40.0
const PAD_Y = 50.0

# Cell types
const EMPTY = 0
const WALL  = 1
const OBS   = 2   # observer — emits a sight ray
const MIR_F = 3   # / mirror
const MIR_B = 4   # \ mirror
const TGT   = 5   # target tile
const SLOT  = 6   # empty placeable slot

# Directions (index used throughout)
const RT = 0
const DN = 1
const LT = 2
const UP = 3

# Direction delta: [right, down, left, up]  (x=col delta, y=row delta)
const DIR_V = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

# ── Colours ───────────────────────────────────────────────────────────────────
const C_BG      = Color(0.08, 0.09, 0.12)
const C_WALL    = Color(0.22, 0.23, 0.27)
const C_DARK    = Color(0.11, 0.13, 0.17)
const C_OBS     = Color(0.38, 0.70, 1.00)
const C_MIR     = Color(0.80, 0.84, 0.96)
const C_TGT_OFF = Color(0.48, 0.20, 0.20)
const C_TGT_ON  = Color(1.00, 0.60, 0.10)
const C_RAY     = Color(0.42, 0.84, 1.00, 0.80)
const C_HOVER   = Color(1.00, 1.00, 1.00, 0.13)
const C_UI      = Color(0.58, 0.60, 0.70)
const C_WIN     = Color(0.22, 1.00, 0.45)
const C_TITLE   = Color(0.70, 0.72, 0.82)

# ── Level definitions ─────────────────────────────────────────────────────────
# grid:     2D array [row][col] of cell-type constants (see above)
# obs_dirs: pre-placed observer positions → direction
# hand:     ordered list of piece types the player places one at a time

# Level 1 — Direct line of sight.  Player places observer in slot; ray fires
#            right, hits the target.  No mirrors needed.  Teaches the basics.
#
# Level 2 — Single mirror.  Observer is pre-placed firing RIGHT.  Target sits
#            above, shifted right.  Player places a / mirror to redirect the
#            beam upward.  First aha moment.
#
# Level 3 — Mirror chain.  Observer fires UP.  Two / mirrors must be chained
#            to bend the path twice (UP→RIGHT→UP) before reaching the target.
#            Demonstrates depth escalation from a single rule set.

var LEVELS: Array = [
	{
		"title": "Level 1 — Line of Sight",
		"grid": [
			[1, 1, 1, 1, 1, 1, 1],
			[1, 6, 0, 0, 0, 5, 1],
			[1, 0, 0, 0, 0, 0, 1],
			[1, 0, 0, 0, 0, 0, 1],
			[1, 0, 0, 0, 0, 0, 1],
			[1, 1, 1, 1, 1, 1, 1],
		],
		"obs_dirs": {},
		"hand": [OBS],
	},
	{
		"title": "Level 2 — Reflection",
		"grid": [
			[1, 1, 1, 1, 1, 1, 1],
			[1, 0, 0, 5, 0, 0, 1],
			[1, 0, 0, 0, 0, 0, 1],
			[1, 2, 0, 6, 0, 0, 1],
			[1, 0, 0, 0, 0, 0, 1],
			[1, 1, 1, 1, 1, 1, 1],
		],
		"obs_dirs": {Vector2i(3, 1): RT},
		"hand": [MIR_F],
	},
	{
		"title": "Level 3 — Mirror Chain",
		"grid": [
			[1, 1, 1, 1, 1, 1, 1],
			[1, 0, 0, 5, 0, 0, 1],
			[1, 0, 0, 0, 0, 0, 1],
			[1, 6, 0, 6, 0, 0, 1],
			[1, 2, 0, 0, 0, 0, 1],
			[1, 1, 1, 1, 1, 1, 1],
		],
		"obs_dirs": {Vector2i(4, 1): UP},
		"hand": [MIR_F, MIR_F],
	},
]

# ── Mutable state ─────────────────────────────────────────────────────────────
var level_idx : int     = 0
var grid      : Array   = []
var obs_dirs  : Dictionary = {}   # Vector2i(r,c) → direction int
var hand      : Array   = []      # remaining pieces to place
var lit       : Dictionary = {}   # Vector2i(r,c) → bool  (targets)
var ray_segs  : Array   = []      # [{from: Vector2, to: Vector2}]
var hover_cell: Vector2i = Vector2i(-1, -1)
var win       : bool    = false
var font      : Font

# ── Init ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	font = ThemeDB.fallback_font
	load_level(0)

func load_level(idx: int) -> void:
	level_idx = idx
	var def: Dictionary = LEVELS[idx]

	grid = []
	for row: Array in def["grid"]:
		grid.append(row.duplicate())

	obs_dirs = {}
	for k: Vector2i in def["obs_dirs"]:
		obs_dirs[k] = def["obs_dirs"][k]

	hand = def["hand"].duplicate()
	lit  = {}
	ray_segs   = []
	win        = false
	hover_cell = Vector2i(-1, -1)

	_update_rays()
	queue_redraw()

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
	var newly_lit_targets: Array[Vector2i] = []

	# Track previous lit state for detecting newly lit targets
	var previously_lit: Dictionary = lit.duplicate()

	lit = {}
	for r in range(ROWS):
		for c in range(COLS):
			if grid[r][c] == TGT:
				lit[Vector2i(r, c)] = false

	for cell: Vector2i in obs_dirs.keys():
		if in_bounds(cell.x, cell.y) and grid[cell.x][cell.y] == OBS:
			_trace_ray(cell.x, cell.y, obs_dirs[cell])

	# Detect newly lit targets and trigger audio
	for target_pos: Vector2i in lit.keys():
		if lit[target_pos] and not previously_lit.get(target_pos, false):
			newly_lit_targets.append(target_pos)

	var all_lit := lit.size() > 0
	for cell: Vector2i in lit.keys():
		if not lit[cell]:
			all_lit = false
			break

	# AUDIO: Trigger win celebration on state change
	if all_lit and not win:
		AudioManager.evt_level_complete()

	# AUDIO: Play target hit sounds for newly illuminated targets
	for i in range(newly_lit_targets.size()):
		AudioManager.evt_target_lit(i)

	win = all_lit
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
			# Boundary — draw to midpoint
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
		else:  # EMPTY, SLOT, OBS — pass through
			ray_segs.append({"from": prev, "to": cur})
			r = nr; c = nc; prev = cur

func _reflect(d: int, is_fwd: bool) -> int:
	# / mirror: RT→UP, DN→LT, LT→DN, UP→RT
	# \ mirror: RT→DN, DN→RT, LT→UP, UP→LT
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
	if win:
		if event is InputEventMouseButton and event.pressed:
			var next := (level_idx + 1) % LEVELS.size()

			# AUDIO: Level transition sound
			await AudioManager.evt_advance_level()

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

			# AUDIO: Piece placement confirmation
			AudioManager.evt_piece_placed()

			_update_rays()
		elif t == MIR_F:
			grid[r][c] = MIR_B

			# AUDIO: Mirror flip confirmation
			AudioManager.evt_mirror_flipped()

			_update_rays()
		elif t == MIR_B:
			grid[r][c] = MIR_F

			# AUDIO: Mirror flip confirmation
			AudioManager.evt_mirror_flipped()

			_update_rays()

# ── Drawing ───────────────────────────────────────────────────────────────────
func _draw() -> void:
	draw_rect(Rect2(0, 0, 760, 580), C_BG)

	# Cells
	for r in range(ROWS):
		for c in range(COLS):
			var rect := Rect2(PAD_X + c * CELL, PAD_Y + r * CELL, CELL, CELL)
			var t: int = grid[r][c]
			var pos  := Vector2i(r, c)
			match t:
				WALL:  draw_rect(rect, C_WALL)
				_:     draw_rect(rect, C_DARK)

			match t:
				SLOT:    _draw_slot_border(rect)
				OBS:     _draw_observer(rect, obs_dirs.get(pos, RT))
				MIR_F:   _draw_mirror(rect, true)
				MIR_B:   _draw_mirror(rect, false)
				TGT:     _draw_target(rect, lit.get(pos, false))

			if pos == hover_cell and t == SLOT and hand.size() > 0:
				draw_rect(rect, C_HOVER)

	# Rays (drawn on top of cells, under grid lines)
	for seg: Dictionary in ray_segs:
		draw_line(seg["from"], seg["to"], C_RAY, 3.0, true)

	# Grid lines
	for r in range(ROWS + 1):
		draw_line(
			Vector2(PAD_X,               PAD_Y + r * CELL),
			Vector2(PAD_X + COLS * CELL, PAD_Y + r * CELL),
			Color(0, 0, 0, 0.25), 1
		)
	for c in range(COLS + 1):
		draw_line(
			Vector2(PAD_X + c * CELL, PAD_Y),
			Vector2(PAD_X + c * CELL, PAD_Y + ROWS * CELL),
			Color(0, 0, 0, 0.25), 1
		)

	_draw_hud()

	if win:
		_draw_win_overlay()

# ── Draw helpers ──────────────────────────────────────────────────────────────
func _draw_slot_border(rect: Rect2) -> void:
	var steps := 5
	var col   := Color(0.28, 0.32, 0.40, 0.8)
	var corners := [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	for i in range(4):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		for s in range(steps):
			if s % 2 == 0:
				var t0 := float(s)       / steps
				var t1 := float(s + 1)   / steps
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
	var m  := CELL * 0.16
	var p  := rect.position
	var e  := rect.end
	if is_fwd:
		draw_line(Vector2(e.x - m, p.y + m), Vector2(p.x + m, e.y - m), C_MIR, 4.0, true)
	else:
		draw_line(Vector2(p.x + m, p.y + m), Vector2(e.x - m, e.y - m), C_MIR, 4.0, true)

func _draw_target(rect: Rect2, is_lit: bool) -> void:
	var cx := rect.position.x + CELL * 0.5
	var cy := rect.position.y + CELL * 0.5
	var r  := CELL * 0.26
	var col := C_TGT_ON if is_lit else C_TGT_OFF

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(cx,     cy - r),
			Vector2(cx + r, cy    ),
			Vector2(cx,     cy + r),
			Vector2(cx - r, cy    ),
		]),
		col
	)
	if is_lit:
		draw_arc(Vector2(cx, cy), r * 1.45, 0.0, TAU, 32, col.lightened(0.35), 2.0, true)

func _draw_hud() -> void:
	# Level title
	var title: String = LEVELS[level_idx]["title"]
	draw_string(font, Vector2(PAD_X, PAD_Y - 12.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_TITLE)

	# Hand panel
	var hx := PAD_X + COLS * CELL + 18.0
	var hy := PAD_Y + 8.0

	if hand.size() > 0:
		draw_string(font, Vector2(hx, hy + 14), "Place:",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_UI)
		var pw := CELL * 0.72
		for i in range(hand.size()):
			var piece: int = hand[i]
			var py   := hy + 24.0 + i * (pw + 10.0)
			var prect := Rect2(hx, py, pw, pw)
			draw_rect(prect, C_DARK)
			_draw_slot_border(prect)
			match piece:
				OBS:   _draw_observer(prect, RT)
				MIR_F: _draw_mirror(prect, true)
				MIR_B: _draw_mirror(prect, false)

		# Hint for placed mirrors
		if grid_has_placed_mirror():
			draw_string(font, Vector2(hx, hy + 24.0 + hand.size() * (pw + 10.0) + 16.0),
				"click placed\nmirror to flip",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(0.48, 0.50, 0.60))
	else:
		draw_string(font, Vector2(hx, hy + 14), "All placed",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.48, 0.72, 0.48))

	# Level counter bottom-right
	var counter := "%d / %d" % [level_idx + 1, LEVELS.size()]
	draw_string(font, Vector2(700, 558), counter,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_UI)

func grid_has_placed_mirror() -> bool:
	for r in range(ROWS):
		for c in range(COLS):
			if grid[r][c] == MIR_F or grid[r][c] == MIR_B:
				return true
	return false

func _draw_win_overlay() -> void:
	draw_rect(Rect2(0, 0, 760, 580), Color(0, 0, 0, 0.52))

	var cx := 380.0
	var cy := 250.0

	# Panel
	draw_rect(Rect2(cx - 170, cy - 60, 340, 140), Color(0.08, 0.11, 0.14, 0.95))

	draw_string(font, Vector2(cx - 140, cy - 24), "All targets illuminated",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, C_WIN)

	var sub := "Click to continue" if level_idx + 1 < LEVELS.size() else "Prototype complete  —  click to restart"
	draw_string(font, Vector2(cx - 140, cy + 18), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_UI)
