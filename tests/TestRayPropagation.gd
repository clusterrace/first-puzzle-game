# TestRayPropagation.gd — Unit tests for RayPropagation (KAMA-16).
#
# Run headless: godot --headless --script tests/TestRayPropagation.gd
#
# Coordinate convention: Vector2i(row, col) — pos.x = row, pos.y = col.
# Matches GridEnums.DIRECTION_DELTA (KAMA-11 convention).
#
# Covers all KAMA-16 acceptance criteria:
#   ✓ Rays travel in straight lines and stop at walls
#   ✓ Forward-slash mirror: all 4 directional reflection cases
#   ✓ Backslash mirror: all 4 directional reflection cases
#   ✓ Non-reflective face pass-through (unknown piece type)
#   ✓ Multiple rays can overlap on the same tile (E1)
#   ✓ Rays pass through observer tiles (E9)
#   ✓ Rays pass through and light target tiles
#   ✓ Full recalculate: clears lit states, propagates, returns win flag
#   ✓ No infinite loop possible (E5 — mirror chain terminates at boundary)
#   ✓ Edge case E2: observer adjacent to wall (path length = 1)

extends SceneTree


# ── Runner ────────────────────────────────────────────────────────────────────

var _pass_count: int = 0
var _fail_count: int = 0
var _current_suite: String = ""


func _init() -> void:
	print("\n=== TestRayPropagation ===\n")

	suite("reflect() — forward-slash mirror (/)")
	test_reflect_forward_slash_all_directions()

	suite("reflect() — backslash mirror (\\)")
	test_reflect_backslash_all_directions()

	suite("reflect() — non-mirror piece type")
	test_reflect_passthrough_non_mirror()

	suite("propagate_ray() — straight line to wall")
	test_ray_straight_line_to_wall()

	suite("propagate_ray() — E2: observer adjacent to wall")
	test_ray_wall_adjacent()

	suite("propagate_ray() — boundary exit without wall")
	test_ray_boundary_exit()

	suite("propagate_ray() — target pass-through and lighting")
	test_ray_through_target()

	suite("propagate_ray() — E9: ray passes through observer tile")
	test_ray_through_observer()

	suite("propagate_ray() — / mirror deflects EAST to NORTH")
	test_ray_forward_slash_east_to_north()

	suite("propagate_ray() — / mirror deflects SOUTH to WEST")
	test_ray_forward_slash_south_to_west()

	suite("propagate_ray() — \\ mirror deflects EAST to SOUTH")
	test_ray_backslash_east_to_south()

	suite("propagate_ray() — \\ mirror deflects NORTH to WEST")
	test_ray_backslash_north_to_west()

	suite("propagate_ray() — E5: mirror chain terminates at boundary")
	test_ray_mirror_chain_terminates()

	suite("recalculate() — clears pre-lit targets with no observers")
	test_recalculate_clears_lit()

	suite("recalculate() — ray_paths keyed by observer position")
	test_recalculate_ray_paths_keys()

	suite("recalculate() — E1: two rays overlap on same target")
	test_recalculate_overlapping_rays()

	suite("recalculate() — win=true when all targets lit")
	test_recalculate_win_true()

	suite("recalculate() — win=false when any target unlit")
	test_recalculate_win_partial()

	suite("check_win() — no targets = no win")
	test_check_win_no_targets()

	suite("check_win() — all targets lit = win")
	test_check_win_all_lit()

	suite("check_win() — one target unlit = no win")
	test_check_win_partial()

	_print_summary()
	quit(1 if _fail_count > 0 else 0)


# ── reflect() tests ───────────────────────────────────────────────────────────

func test_reflect_forward_slash_all_directions() -> void:
	# Spec Section 4.2 — / mirror: N→E, E→N, S→W, W→S
	expect_eq(
		RayPropagation.reflect(GridEnums.Direction.NORTH, GridEnums.PieceType.MIRROR_FWDSLASH),
		GridEnums.Direction.EAST,  "/ mirror: NORTH → EAST")
	expect_eq(
		RayPropagation.reflect(GridEnums.Direction.EAST, GridEnums.PieceType.MIRROR_FWDSLASH),
		GridEnums.Direction.NORTH, "/ mirror: EAST → NORTH")
	expect_eq(
		RayPropagation.reflect(GridEnums.Direction.SOUTH, GridEnums.PieceType.MIRROR_FWDSLASH),
		GridEnums.Direction.WEST,  "/ mirror: SOUTH → WEST")
	expect_eq(
		RayPropagation.reflect(GridEnums.Direction.WEST, GridEnums.PieceType.MIRROR_FWDSLASH),
		GridEnums.Direction.SOUTH, "/ mirror: WEST → SOUTH")


func test_reflect_backslash_all_directions() -> void:
	# Spec Section 4.2 — \ mirror: N→W, W→N, S→E, E→S
	expect_eq(
		RayPropagation.reflect(GridEnums.Direction.NORTH, GridEnums.PieceType.MIRROR_BKSLASH),
		GridEnums.Direction.WEST,  "\\ mirror: NORTH → WEST")
	expect_eq(
		RayPropagation.reflect(GridEnums.Direction.WEST, GridEnums.PieceType.MIRROR_BKSLASH),
		GridEnums.Direction.NORTH, "\\ mirror: WEST → NORTH")
	expect_eq(
		RayPropagation.reflect(GridEnums.Direction.SOUTH, GridEnums.PieceType.MIRROR_BKSLASH),
		GridEnums.Direction.EAST,  "\\ mirror: SOUTH → EAST")
	expect_eq(
		RayPropagation.reflect(GridEnums.Direction.EAST, GridEnums.PieceType.MIRROR_BKSLASH),
		GridEnums.Direction.SOUTH, "\\ mirror: EAST → SOUTH")


func test_reflect_passthrough_non_mirror() -> void:
	# OBSERVER piece type — not a mirror — direction unchanged
	expect_eq(
		RayPropagation.reflect(GridEnums.Direction.EAST, GridEnums.PieceType.OBSERVER),
		GridEnums.Direction.EAST,  "OBSERVER piece: direction unchanged")
	# NONE piece type
	expect_eq(
		RayPropagation.reflect(GridEnums.Direction.NORTH, GridEnums.PieceType.NONE),
		GridEnums.Direction.NORTH, "NONE piece: direction unchanged")


# ── propagate_ray() tests ─────────────────────────────────────────────────────

func test_ray_straight_line_to_wall() -> void:
	# 1 row, 5 cols. OBSERVER at (0,0) facing EAST. WALL at (0,4).
	# Expected path: (0,1), (0,2), (0,3), (0,4) — wall tile is terminal.
	var g := MockGrid.new(1, 5)
	g.set_piece(0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	g.set_tile(0, 4, GridEnums.TileType.WALL)

	var path: Array = RayPropagation.propagate_ray(g, Vector2i(0, 0), GridEnums.Direction.EAST)

	expect_eq(path.size(), 4, "path visits 4 tiles including wall")
	expect_eq(path[0], Vector2i(0, 1), "first tile (0,1)")
	expect_eq(path[3], Vector2i(0, 4), "last tile is wall (0,4)")


func test_ray_wall_adjacent() -> void:
	# E2: observer directly adjacent to wall. Path length must be 1.
	var g := MockGrid.new(1, 3)
	g.set_piece(0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	g.set_tile(0, 1, GridEnums.TileType.WALL)

	var path: Array = RayPropagation.propagate_ray(g, Vector2i(0, 0), GridEnums.Direction.EAST)

	expect_eq(path.size(), 1, "E2: path length = 1 when wall is adjacent")
	expect_eq(path[0], Vector2i(0, 1), "E2: only tile is the wall")


func test_ray_boundary_exit() -> void:
	# No wall — ray exits grid at boundary.
	var g := MockGrid.new(1, 3)
	g.set_piece(0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	# No wall, no targets — ray exits at right boundary

	var path: Array = RayPropagation.propagate_ray(g, Vector2i(0, 0), GridEnums.Direction.EAST)

	expect_eq(path.size(), 2, "ray visits (0,1) and (0,2) before exiting grid")
	expect_eq(path[1], Vector2i(0, 2), "last visited tile is (0,2)")


func test_ray_through_target() -> void:
	# TARGET at (0,2), WALL at (0,4). Ray must light target AND continue to wall.
	var g := MockGrid.new(1, 5)
	g.set_piece(0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	g.set_tile(0, 2, GridEnums.TileType.TARGET)
	g.set_tile(0, 4, GridEnums.TileType.WALL)

	var path: Array = RayPropagation.propagate_ray(g, Vector2i(0, 0), GridEnums.Direction.EAST)

	expect_eq(path.size(), 4, "ray continues past target, stops at wall")
	expect_true(g.is_target_lit(Vector2i(0, 2)), "target (0,2) is lit")
	expect_true(path.has(Vector2i(0, 4)), "wall (0,4) is in path as terminal tile")


func test_ray_through_observer() -> void:
	# E9: ray passes through another observer tile unchanged.
	# OBS at (0,0) EAST; second OBS at (0,2) facing NORTH; WALL at (0,4).
	var g := MockGrid.new(1, 5)
	g.set_piece(0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	g.set_piece(0, 2, GridEnums.PieceType.OBSERVER, GridEnums.Direction.NORTH)
	g.set_tile(0, 4, GridEnums.TileType.WALL)

	var path: Array = RayPropagation.propagate_ray(g, Vector2i(0, 0), GridEnums.Direction.EAST)

	expect_eq(path.size(), 4, "E9: path includes observer tile (0,2) and continues to wall")
	expect_true(path.has(Vector2i(0, 2)), "E9: observer tile (0,2) is in path")
	expect_eq(path[3], Vector2i(0, 4), "E9: ray continues to wall")


func test_ray_forward_slash_east_to_north() -> void:
	# OBS at (2,0) facing EAST. / mirror at (2,3). TARGET at (0,3).
	# Ray goes EAST → hits / mirror → deflects NORTH → lights target.
	#
	# Grid (row, col): 3 rows × 5 cols
	# (0,3) = TARGET
	# (1,3) = SLOT (passable)
	# (2,0) = OBSERVER facing EAST
	# (2,3) = / mirror
	var g := MockGrid.new(3, 5)
	g.set_piece(2, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	g.set_piece(2, 3, GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.Direction.NORTH)
	g.set_tile(0, 3, GridEnums.TileType.TARGET)

	var path: Array = RayPropagation.propagate_ray(g, Vector2i(2, 0), GridEnums.Direction.EAST)

	expect_true(path.has(Vector2i(2, 3)), "/ mirror tile in path")
	expect_true(path.has(Vector2i(0, 3)), "target north of mirror in path")
	expect_true(g.is_target_lit(Vector2i(0, 3)), "target (0,3) lit after / EAST→NORTH reflection")


func test_ray_forward_slash_south_to_west() -> void:
	# OBS at (0,3) facing SOUTH. / mirror at (3,3). TARGET at (3,0).
	# Ray goes SOUTH → hits / mirror → deflects WEST → lights target.
	var g := MockGrid.new(5, 5)
	g.set_piece(0, 3, GridEnums.PieceType.OBSERVER, GridEnums.Direction.SOUTH)
	g.set_piece(3, 3, GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.Direction.NORTH)
	g.set_tile(3, 0, GridEnums.TileType.TARGET)

	var path: Array = RayPropagation.propagate_ray(g, Vector2i(0, 3), GridEnums.Direction.SOUTH)

	expect_true(path.has(Vector2i(3, 3)), "/ mirror tile in path")
	expect_true(path.has(Vector2i(3, 0)), "target west of mirror in path")
	expect_true(g.is_target_lit(Vector2i(3, 0)), "target (3,0) lit after / SOUTH→WEST reflection")


func test_ray_backslash_east_to_south() -> void:
	# OBS at (2,0) facing EAST. \ mirror at (2,3). TARGET at (4,3).
	# Ray goes EAST → hits \ mirror → deflects SOUTH → lights target.
	var g := MockGrid.new(6, 5)
	g.set_piece(2, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	g.set_piece(2, 3, GridEnums.PieceType.MIRROR_BKSLASH, GridEnums.Direction.NORTH)
	g.set_tile(4, 3, GridEnums.TileType.TARGET)

	var path: Array = RayPropagation.propagate_ray(g, Vector2i(2, 0), GridEnums.Direction.EAST)

	expect_true(path.has(Vector2i(2, 3)), "\\ mirror tile in path")
	expect_true(path.has(Vector2i(4, 3)), "target south of \\ mirror in path")
	expect_true(g.is_target_lit(Vector2i(4, 3)), "target (4,3) lit after \\ EAST→SOUTH reflection")


func test_ray_backslash_north_to_west() -> void:
	# OBS at (4,3) facing NORTH. \ mirror at (1,3). TARGET at (1,0).
	# Ray goes NORTH → hits \ mirror → deflects WEST → lights target.
	var g := MockGrid.new(6, 5)
	g.set_piece(4, 3, GridEnums.PieceType.OBSERVER, GridEnums.Direction.NORTH)
	g.set_piece(1, 3, GridEnums.PieceType.MIRROR_BKSLASH, GridEnums.Direction.NORTH)
	g.set_tile(1, 0, GridEnums.TileType.TARGET)

	var path: Array = RayPropagation.propagate_ray(g, Vector2i(4, 3), GridEnums.Direction.NORTH)

	expect_true(path.has(Vector2i(1, 3)), "\\ mirror tile in path")
	expect_true(path.has(Vector2i(1, 0)), "target west of \\ mirror in path")
	expect_true(g.is_target_lit(Vector2i(1, 0)), "target (1,0) lit after \\ NORTH→WEST reflection")


func test_ray_mirror_chain_terminates() -> void:
	# E5: a / mirror at the far end of a row. Ray going EAST hits it, deflects NORTH,
	# exits the grid boundary. No infinite loop.
	#
	# 3 rows, 5 cols.
	# (1,0) = OBSERVER facing EAST
	# (1,4) = / mirror → EAST→NORTH deflection
	# After reflection, ray travels NORTH and exits at row -1.
	var g := MockGrid.new(3, 5)
	g.set_piece(1, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	g.set_piece(1, 4, GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.Direction.NORTH)

	var path: Array = RayPropagation.propagate_ray(g, Vector2i(1, 0), GridEnums.Direction.EAST)

	# (1,1), (1,2), (1,3), (1,4)[mirror], (0,4) — then row -1 exits bounds
	expect_eq(path.size(), 5, "E5: path terminates at boundary after mirror chain")
	expect_eq(path[3], Vector2i(1, 4), "E5: mirror tile at (1,4) in path")
	expect_eq(path[4], Vector2i(0, 4), "E5: first reflected tile (0,4) before exit")


# ── recalculate() tests ───────────────────────────────────────────────────────

func test_recalculate_clears_lit() -> void:
	# Pre-light a target, then recalculate with no observers — must clear it.
	var g := MockGrid.new(3, 3)
	g.set_tile(1, 1, GridEnums.TileType.TARGET)
	g.set_target_lit(Vector2i(1, 1), true)  # manually pre-lit

	var result: Dictionary = RayPropagation.recalculate(g)

	expect_false(g.is_target_lit(Vector2i(1, 1)), "recalculate cleared pre-lit target")
	expect_false(result["win"], "win=false after clearing with no observers")


func test_recalculate_ray_paths_keys() -> void:
	# Two observers: both should appear as keys in ray_paths.
	var g := MockGrid.new(3, 5)
	g.set_piece(0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	g.set_piece(2, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)

	var result: Dictionary = RayPropagation.recalculate(g)

	expect_true(result["ray_paths"].has(Vector2i(0, 0)), "ray_paths contains observer O1")
	expect_true(result["ray_paths"].has(Vector2i(2, 0)), "ray_paths contains observer O2")


func test_recalculate_overlapping_rays() -> void:
	# E1: O1 fires EAST, O2 fires SOUTH, both cross TARGET at (2,2).
	# Grid: 4 rows × 4 cols.
	# (2,0) = OBSERVER → EAST
	# (0,2) = OBSERVER → SOUTH
	# (2,2) = TARGET
	var g := MockGrid.new(4, 4)
	g.set_piece(2, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	g.set_piece(0, 2, GridEnums.PieceType.OBSERVER, GridEnums.Direction.SOUTH)
	g.set_tile(2, 2, GridEnums.TileType.TARGET)

	var result: Dictionary = RayPropagation.recalculate(g)

	expect_true(g.is_target_lit(Vector2i(2, 2)), "E1: target lit by overlapping rays")
	expect_true(result["win"], "E1: win when sole target is lit by overlapping rays")


func test_recalculate_win_true() -> void:
	# Single observer, single target in line → win = true.
	var g := MockGrid.new(1, 5)
	g.set_piece(0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	g.set_tile(0, 3, GridEnums.TileType.TARGET)

	var result: Dictionary = RayPropagation.recalculate(g)

	expect_true(result["win"], "win=true when sole target is in ray path")


func test_recalculate_win_partial() -> void:
	# Two targets, only one in ray path → win = false.
	var g := MockGrid.new(1, 6)
	g.set_piece(0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	g.set_tile(0, 2, GridEnums.TileType.TARGET)  # in ray path — lit
	g.set_tile(0, 5, GridEnums.TileType.TARGET)  # also in ray path... wait, need wall
	# Add wall at (0,3) so ray stops before (0,5)
	g.set_tile(0, 3, GridEnums.TileType.WALL)
	# Now only (0,2) is lit, (0,5) is not

	var result: Dictionary = RayPropagation.recalculate(g)

	expect_true(g.is_target_lit(Vector2i(0, 2)),   "target (0,2) is lit")
	expect_false(g.is_target_lit(Vector2i(0, 5)),  "target (0,5) is unlit (behind wall)")
	expect_false(result["win"], "win=false when one target is unlit")


# ── check_win() tests ─────────────────────────────────────────────────────────

func test_check_win_no_targets() -> void:
	var g := MockGrid.new(3, 3)
	expect_false(RayPropagation.check_win(g), "no win on grid with no targets")


func test_check_win_all_lit() -> void:
	var g := MockGrid.new(3, 3)
	g.set_tile(0, 1, GridEnums.TileType.TARGET)
	g.set_tile(2, 1, GridEnums.TileType.TARGET)
	g.set_target_lit(Vector2i(0, 1), true)
	g.set_target_lit(Vector2i(2, 1), true)
	expect_true(RayPropagation.check_win(g), "win when all targets are lit")


func test_check_win_partial() -> void:
	var g := MockGrid.new(3, 3)
	g.set_tile(0, 1, GridEnums.TileType.TARGET)
	g.set_tile(2, 1, GridEnums.TileType.TARGET)
	g.set_target_lit(Vector2i(0, 1), true)
	# (2,1) stays unlit
	expect_false(RayPropagation.check_win(g), "no win when one target is unlit")


# ── Assertion helpers ─────────────────────────────────────────────────────────

func suite(name: String) -> void:
	_current_suite = name


func expect_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		_pass("[PASS] %s — %s" % [_current_suite, label])
	else:
		_fail("[FAIL] %s — %s\n       expected: %s\n       got:      %s" % [
			_current_suite, label, str(expected), str(actual)])


func expect_true(value: bool, label: String) -> void:
	if value:
		_pass("[PASS] %s — %s" % [_current_suite, label])
	else:
		_fail("[FAIL] %s — %s  (expected true, got false)" % [_current_suite, label])


func expect_false(value: bool, label: String) -> void:
	if not value:
		_pass("[PASS] %s — %s" % [_current_suite, label])
	else:
		_fail("[FAIL] %s — %s  (expected false, got true)" % [_current_suite, label])


func _pass(msg: String) -> void:
	print(msg)
	_pass_count += 1


func _fail(msg: String) -> void:
	printerr(msg)
	_fail_count += 1


func _print_summary() -> void:
	var divider := "────────────────────────────────"
	print("\n" + divider)
	if _fail_count == 0:
		print("Results: %d / %d passed. All tests passed." % [_pass_count, _pass_count])
	else:
		printerr("Results: %d passed, %d FAILED." % [_pass_count, _fail_count])
	print(divider + "\n")


# ── MockGrid ──────────────────────────────────────────────────────────────────
# Implements the RayPropagation grid interface for isolated unit testing.
#
# Coordinate convention: Vector2i(row, col) — matches GridEnums.DIRECTION_DELTA.
# Construction: MockGrid.new(rows, cols).
# Tile/piece defaults: TileType.SLOT, PieceType.NONE, Direction.EAST.

class MockGrid:
	var _rows: int
	var _cols: int
	## _tile_grid[row][col] → GridEnums.TileType int
	var _tile_grid: Array
	## _piece_grid[row][col] → GridEnums.PieceType int
	var _piece_grid: Array
	## _piece_dir[row][col] → GridEnums.Direction int
	var _piece_dir: Array
	## _target_lit: Dictionary { Vector2i(row,col) → bool }
	var _target_lit: Dictionary

	func _init(rows: int, cols: int) -> void:
		_rows = rows
		_cols = cols
		_target_lit = {}
		_tile_grid  = []
		_piece_grid = []
		_piece_dir  = []
		for _r in range(rows):
			var tile_row:  Array = []
			var piece_row: Array = []
			var dir_row:   Array = []
			for _c in range(cols):
				tile_row.append(GridEnums.TileType.SLOT)
				piece_row.append(GridEnums.PieceType.NONE)
				dir_row.append(GridEnums.Direction.EAST)
			_tile_grid.append(tile_row)
			_piece_grid.append(piece_row)
			_piece_dir.append(dir_row)

	## Set base tile type for cell (row, col).
	## Automatically registers TARGET cells in the lit-state dict.
	func set_tile(row: int, col: int, tile_type: int) -> void:
		_tile_grid[row][col] = tile_type
		var pos := Vector2i(row, col)
		if tile_type == GridEnums.TileType.TARGET:
			_target_lit[pos] = false
		elif _target_lit.has(pos):
			_target_lit.erase(pos)

	## Place a piece at cell (row, col) with given type and facing direction.
	func set_piece(row: int, col: int, piece_type: int, direction: int) -> void:
		_piece_grid[row][col] = piece_type
		_piece_dir[row][col]  = direction

	## ── RayPropagation grid interface ─────────────────────────────────────────

	func get_tile_type(pos: Vector2i) -> int:
		return _tile_grid[pos.x][pos.y]

	func get_piece_type(pos: Vector2i) -> int:
		return _piece_grid[pos.x][pos.y]

	func get_piece_direction(pos: Vector2i) -> int:
		return _piece_dir[pos.x][pos.y]

	func get_all_observers() -> Array:
		var result: Array = []
		for r in range(_rows):
			for c in range(_cols):
				if _piece_grid[r][c] == GridEnums.PieceType.OBSERVER:
					result.append(Vector2i(r, c))
		return result

	func get_all_targets() -> Array:
		return _target_lit.keys()

	func set_target_lit(pos: Vector2i, lit: bool) -> void:
		if _target_lit.has(pos):
			_target_lit[pos] = lit

	func is_target_lit(pos: Vector2i) -> bool:
		return _target_lit.get(pos, false)

	func is_in_bounds(pos: Vector2i) -> bool:
		return pos.x >= 0 and pos.x < _rows and pos.y >= 0 and pos.y < _cols
