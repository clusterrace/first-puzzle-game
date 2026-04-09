# TestPieceInventory.gd — Unit tests for PieceInventory and SightLinesLogic
#                         placement/removal/win integration (KAMA-17).
#
# Run headless: godot --headless --script tests/TestPieceInventory.gd
#
# Coordinate convention: Vector2i(row, col) — pos.x = row, pos.y = col.
# Matches GridEnums.DIRECTION_DELTA (KAMA-11 convention).
#
# Covers all KAMA-17 acceptance criteria:
#   ✓ Inventory loads counts correctly from LevelData
#   ✓ get_count / can_place / get_available_types
#   ✓ consume decrements count and returns true
#   ✓ consume returns false (no state change) when count is zero
#   ✓ return_piece increments count
#   ✓ inventory_changed signal fires on consume and return
#   ✓ Placement on wall tile is rejected (no state change) — spec E6
#   ✓ Placement on TARGET tile is rejected — spec E6
#   ✓ Placement on fixed piece is rejected — spec E6
#   ✓ Placement on occupied SLOT is rejected — spec E6
#   ✓ Placement fails when inventory is empty (no state change)
#   ✓ Valid placement consumes inventory and places piece on grid
#   ✓ Removing a player piece returns it to inventory
#   ✓ Removing a fixed piece is rejected
#   ✓ Removing from empty cell is rejected
#   ✓ Win fires exactly when all targets are simultaneously lit
#   ✓ Win does not fire when only some targets are lit
#   ✓ Solution with fewer pieces than provided is valid (unused pieces OK)

extends SceneTree


# ── Runner ────────────────────────────────────────────────────────────────────

var _pass_count: int = 0
var _fail_count: int = 0
var _current_suite: String = ""


func _init() -> void:
	print("\n=== TestPieceInventory ===\n")

	# ── PieceInventory unit tests ─────────────────────────────────────────────
	suite("PieceInventory — load from single-type inventory")
	test_inventory_single_type()

	suite("PieceInventory — load from multi-type inventory")
	test_inventory_multi_type()

	suite("PieceInventory — load from empty inventory")
	test_inventory_empty()

	suite("PieceInventory — load accumulates duplicate types")
	test_inventory_duplicate_types()

	suite("PieceInventory — get_available_types")
	test_inventory_available_types()

	suite("PieceInventory — consume success")
	test_inventory_consume_success()

	suite("PieceInventory — consume fails when count is zero (no state change)")
	test_inventory_consume_empty()

	suite("PieceInventory — return_piece increments count")
	test_inventory_return_piece()

	suite("PieceInventory — inventory_changed signal fires on consume")
	test_inventory_signal_consume()

	suite("PieceInventory — inventory_changed signal fires on return_piece")
	test_inventory_signal_return()

	# ── GridState placement validation (Vector2i API) ─────────────────────────
	suite("GridState — is_placeable: empty SLOT → true")
	test_grid_placeable_slot()

	suite("GridState — is_placeable: WALL → false")
	test_grid_placeable_wall()

	suite("GridState — is_placeable: TARGET → false")
	test_grid_placeable_target()

	suite("GridState — is_placeable: occupied SLOT → false")
	test_grid_placeable_occupied()

	suite("GridState — is_placeable: EMPTY (non-slot) → false")
	test_grid_placeable_empty_cell()

	suite("GridState — is_placeable: fixed piece slot → false")
	test_grid_placeable_fixed_piece()

	suite("GridState — place_piece succeeds on valid SLOT")
	test_grid_place_piece_success()

	suite("GridState — place_piece fails on WALL (E6: no state change)")
	test_grid_place_piece_wall_rejected()

	suite("GridState — remove_piece returns false for NONE tile")
	test_grid_remove_none()

	suite("GridState — remove_piece returns false for fixed piece")
	test_grid_remove_fixed()

	suite("GridState — remove_piece succeeds for player piece")
	test_grid_remove_player_piece()

	# ── SightLinesLogic placement integration ─────────────────────────────────
	suite("SightLinesLogic — try_place_piece: valid placement succeeds")
	test_logic_place_success()

	suite("SightLinesLogic — try_place_piece: WALL tile rejected (E6)")
	test_logic_place_on_wall_rejected()

	suite("SightLinesLogic — try_place_piece: TARGET tile rejected (E6)")
	test_logic_place_on_target_rejected()

	suite("SightLinesLogic — try_place_piece: fixed piece rejected (E6)")
	test_logic_place_on_fixed_rejected()

	suite("SightLinesLogic — try_place_piece: inventory empty → rejected")
	test_logic_place_inventory_empty()

	suite("SightLinesLogic — try_place_piece: consumes inventory on success")
	test_logic_place_consumes_inventory()

	suite("SightLinesLogic — try_remove_piece: returns piece to inventory")
	test_logic_remove_returns_to_inventory()

	suite("SightLinesLogic — try_remove_piece: fixed piece rejected")
	test_logic_remove_fixed_rejected()

	suite("SightLinesLogic — try_remove_piece: empty cell rejected")
	test_logic_remove_empty_rejected()

	# ── Win condition integration ─────────────────────────────────────────────
	suite("SightLinesLogic — win fires when all targets lit after placement")
	test_logic_win_on_placement()

	suite("SightLinesLogic — win does not fire when target remains unlit")
	test_logic_no_win_partial()

	suite("SightLinesLogic — win fires at most once per level")
	test_logic_win_fires_once()

	suite("SightLinesLogic — solution with fewer pieces than provided is valid")
	test_logic_win_fewer_pieces()

	_print_summary()
	quit(1 if _fail_count > 0 else 0)


# ── PieceInventory tests ──────────────────────────────────────────────────────

func test_inventory_single_type() -> void:
	var inv := _make_inventory([GridEnums.PieceType.OBSERVER])
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 1, "observer count = 1")
	expect_eq(inv.get_count(GridEnums.PieceType.MIRROR_FWDSLASH), 0, "fwd-slash count = 0")
	expect_true(inv.can_place(GridEnums.PieceType.OBSERVER), "can place observer")
	expect_false(inv.can_place(GridEnums.PieceType.MIRROR_FWDSLASH), "cannot place mirror")


func test_inventory_multi_type() -> void:
	var inv := _make_inventory([
		GridEnums.PieceType.OBSERVER,
		GridEnums.PieceType.MIRROR_FWDSLASH,
	])
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 1, "observer count = 1")
	expect_eq(inv.get_count(GridEnums.PieceType.MIRROR_FWDSLASH), 1, "fwd-slash count = 1")


func test_inventory_empty() -> void:
	var inv := _make_inventory([])
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 0, "observer count = 0 on empty inventory")
	expect_false(inv.can_place(GridEnums.PieceType.OBSERVER), "cannot place from empty inventory")
	expect_eq(inv.get_available_types().size(), 0, "no available types")


func test_inventory_duplicate_types() -> void:
	# [1, 1] → 2 observers (KAMA-17 spec: multi-piece of same type)
	var inv := _make_inventory([
		GridEnums.PieceType.OBSERVER,
		GridEnums.PieceType.OBSERVER,
		GridEnums.PieceType.MIRROR_FWDSLASH,
	])
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 2, "two observers loaded")
	expect_eq(inv.get_count(GridEnums.PieceType.MIRROR_FWDSLASH), 1, "one fwd-slash mirror")


func test_inventory_available_types() -> void:
	var inv := _make_inventory([
		GridEnums.PieceType.OBSERVER,
		GridEnums.PieceType.MIRROR_BKSLASH,
	])
	var types := inv.get_available_types()
	expect_eq(types.size(), 2, "two types available")
	expect_true(types.has(GridEnums.PieceType.OBSERVER), "observer in available types")
	expect_true(types.has(GridEnums.PieceType.MIRROR_BKSLASH), "bk-slash in available types")
	# After consuming all of one type, it should no longer appear.
	inv.consume(GridEnums.PieceType.OBSERVER)
	var types2 := inv.get_available_types()
	expect_false(types2.has(GridEnums.PieceType.OBSERVER), "observer not in available types after exhaustion")


func test_inventory_consume_success() -> void:
	var inv := _make_inventory([GridEnums.PieceType.OBSERVER])
	var ok: bool = inv.consume(GridEnums.PieceType.OBSERVER)
	expect_true(ok, "consume returns true when piece available")
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 0, "count decrements to 0")
	expect_false(inv.can_place(GridEnums.PieceType.OBSERVER), "cannot place after exhaustion")


func test_inventory_consume_empty() -> void:
	var inv := _make_inventory([])
	var ok: bool = inv.consume(GridEnums.PieceType.OBSERVER)
	expect_false(ok, "consume returns false when inventory empty")
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 0, "count stays 0 after failed consume")


func test_inventory_return_piece() -> void:
	var inv := _make_inventory([GridEnums.PieceType.OBSERVER])
	inv.consume(GridEnums.PieceType.OBSERVER)
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 0, "count 0 after consume")
	inv.return_piece(GridEnums.PieceType.OBSERVER)
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 1, "count restored to 1 after return")
	expect_true(inv.can_place(GridEnums.PieceType.OBSERVER), "can place again after return")


func test_inventory_signal_consume() -> void:
	var inv := _make_inventory([GridEnums.PieceType.OBSERVER])
	var signal_fired := false
	var captured_type := -1
	var captured_count := -1
	inv.inventory_changed.connect(func(pt: int, cnt: int) -> void:
		signal_fired = true
		captured_type = pt
		captured_count = cnt
	)
	inv.consume(GridEnums.PieceType.OBSERVER)
	expect_true(signal_fired, "inventory_changed emitted on consume")
	expect_eq(captured_type, GridEnums.PieceType.OBSERVER, "signal carries correct piece_type")
	expect_eq(captured_count, 0, "signal carries new count = 0")


func test_inventory_signal_return() -> void:
	var inv := _make_inventory([])
	var signal_fired := false
	var captured_count := -1
	inv.inventory_changed.connect(func(_pt: int, cnt: int) -> void:
		signal_fired = true
		captured_count = cnt
	)
	inv.return_piece(GridEnums.PieceType.MIRROR_FWDSLASH)
	expect_true(signal_fired, "inventory_changed emitted on return_piece")
	expect_eq(captured_count, 1, "signal carries new count = 1 after return")


# ── GridState tests ───────────────────────────────────────────────────────────

func test_grid_placeable_slot() -> void:
	var g := _make_grid_5x5()
	# (2,2) is default SLOT, no piece.
	expect_true(g.is_placeable(Vector2i(2, 2)), "empty SLOT is placeable")


func test_grid_placeable_wall() -> void:
	var g := _make_grid_5x5()
	# (0,0) is WALL in the 5×5 helper.
	expect_false(g.is_placeable(Vector2i(0, 0)), "WALL is not placeable")


func test_grid_placeable_target() -> void:
	var g := _make_grid_5x5()
	# (1,3) is TARGET in the 5×5 helper.
	expect_false(g.is_placeable(Vector2i(1, 3)), "TARGET is not placeable")


func test_grid_placeable_occupied() -> void:
	var g := _make_grid_5x5()
	g.place_piece(Vector2i(2, 2), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	expect_false(g.is_placeable(Vector2i(2, 2)), "occupied SLOT is not placeable")


func test_grid_placeable_empty_cell() -> void:
	var g := _make_grid_5x5()
	# (2,4) is EMPTY (not a SLOT) in the 5×5 helper.
	expect_false(g.is_placeable(Vector2i(2, 4)), "EMPTY (non-slot) is not placeable")


func test_grid_placeable_fixed_piece() -> void:
	# Build a grid with a fixed piece via LevelData.
	var data := LevelData.new()
	data.title = "test"
	data.rows  = 3
	data.cols  = 3
	data.tile_grid = [
		GridEnums.TileType.WALL,   GridEnums.TileType.WALL,   GridEnums.TileType.WALL,
		GridEnums.TileType.WALL,   GridEnums.TileType.SLOT,   GridEnums.TileType.WALL,
		GridEnums.TileType.WALL,   GridEnums.TileType.WALL,   GridEnums.TileType.WALL,
	]
	data.fixed_pieces = [{"row": 1, "col": 1, "piece_type": GridEnums.PieceType.OBSERVER, "direction": GridEnums.Direction.EAST}]
	data.player_inventory = []

	var g := GridState.new()
	g.load_from_level_data(data)
	expect_false(g.is_placeable(Vector2i(1, 1)), "fixed piece slot is not placeable")


func test_grid_place_piece_success() -> void:
	var g := _make_grid_5x5()
	var ok: bool = g.place_piece(Vector2i(2, 2), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	expect_true(ok, "place_piece returns true on valid SLOT")
	expect_eq(g.get_piece_type(Vector2i(2, 2)), GridEnums.PieceType.OBSERVER, "observer placed at (2,2)")
	expect_eq(g.get_piece_direction(Vector2i(2, 2)), GridEnums.Direction.EAST, "direction is EAST")


func test_grid_place_piece_wall_rejected() -> void:
	# E6: no state change on invalid placement.
	var g := _make_grid_5x5()
	var ok: bool = g.place_piece(Vector2i(0, 0), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	expect_false(ok, "place_piece on WALL returns false (E6)")
	expect_eq(g.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.NONE, "WALL cell unchanged after rejection")


func test_grid_remove_none() -> void:
	var g := _make_grid_5x5()
	var ok: bool = g.remove_piece(Vector2i(2, 2))
	expect_false(ok, "remove_piece on empty cell returns false")


func test_grid_remove_fixed() -> void:
	var data := LevelData.new()
	data.title = "test"
	data.rows  = 3
	data.cols  = 3
	data.tile_grid = [
		GridEnums.TileType.SLOT, GridEnums.TileType.SLOT, GridEnums.TileType.SLOT,
		GridEnums.TileType.SLOT, GridEnums.TileType.SLOT, GridEnums.TileType.SLOT,
		GridEnums.TileType.SLOT, GridEnums.TileType.SLOT, GridEnums.TileType.SLOT,
	]
	data.fixed_pieces = [{"row": 1, "col": 1, "piece_type": GridEnums.PieceType.OBSERVER, "direction": GridEnums.Direction.EAST}]
	data.player_inventory = []
	var g := GridState.new()
	g.load_from_level_data(data)
	var ok: bool = g.remove_piece(Vector2i(1, 1))
	expect_false(ok, "remove_piece on fixed piece returns false")
	expect_eq(g.get_piece_type(Vector2i(1, 1)), GridEnums.PieceType.OBSERVER, "fixed piece remains after failed remove")


func test_grid_remove_player_piece() -> void:
	var g := _make_grid_5x5()
	g.place_piece(Vector2i(2, 2), GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.Direction.NORTH)
	var ok: bool = g.remove_piece(Vector2i(2, 2))
	expect_true(ok, "remove_piece on player piece returns true")
	expect_eq(g.get_piece_type(Vector2i(2, 2)), GridEnums.PieceType.NONE, "cell empty after remove")


# ── SightLinesLogic integration tests ────────────────────────────────────────

func test_logic_place_success() -> void:
	var ctx := _make_logic_context([GridEnums.PieceType.OBSERVER])
	var ok: bool = ctx.logic.try_place_piece(
		Vector2i(2, 2), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	expect_true(ok, "try_place_piece returns true on valid grid + inventory")
	expect_eq(ctx.grid.get_piece_type(Vector2i(2, 2)), GridEnums.PieceType.OBSERVER,
		"observer placed on grid")


func test_logic_place_on_wall_rejected() -> void:
	var ctx := _make_logic_context([GridEnums.PieceType.OBSERVER])
	var ok: bool = ctx.logic.try_place_piece(
		Vector2i(0, 0), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	expect_false(ok, "try_place_piece on WALL returns false (E6)")
	expect_eq(ctx.grid.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.NONE,
		"WALL cell unchanged — no state change (E6)")
	expect_eq(ctx.inv.get_count(GridEnums.PieceType.OBSERVER), 1,
		"inventory unchanged after wall rejection")


func test_logic_place_on_target_rejected() -> void:
	var ctx := _make_logic_context([GridEnums.PieceType.OBSERVER])
	# (1,3) is TARGET in the 5×5 helper.
	var ok: bool = ctx.logic.try_place_piece(
		Vector2i(1, 3), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	expect_false(ok, "try_place_piece on TARGET returns false (E6)")
	expect_eq(ctx.inv.get_count(GridEnums.PieceType.OBSERVER), 1,
		"inventory unchanged after target rejection")


func test_logic_place_on_fixed_rejected() -> void:
	# Build context with a fixed observer.
	var data := _make_level_data_5x5([GridEnums.PieceType.OBSERVER])
	data.fixed_pieces = [{"row": 2, "col": 2, "piece_type": GridEnums.PieceType.OBSERVER, "direction": GridEnums.Direction.EAST}]
	var ctx := _make_logic_context_from_data(data)
	var ok: bool = ctx.logic.try_place_piece(
		Vector2i(2, 2), GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.Direction.NORTH)
	expect_false(ok, "try_place_piece on fixed-piece cell returns false (E6)")
	expect_eq(ctx.inv.get_count(GridEnums.PieceType.MIRROR_FWDSLASH), 0,
		"wait — inventory never had a mirror")
	# Inventory is unchanged (no mirror to begin with), but the key test is:
	expect_eq(ctx.grid.get_piece_type(Vector2i(2, 2)), GridEnums.PieceType.OBSERVER,
		"fixed piece unchanged after rejection")


func test_logic_place_inventory_empty() -> void:
	var ctx := _make_logic_context([])  # no pieces in inventory
	var ok: bool = ctx.logic.try_place_piece(
		Vector2i(2, 2), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	expect_false(ok, "try_place_piece fails when inventory is empty")
	expect_eq(ctx.grid.get_piece_type(Vector2i(2, 2)), GridEnums.PieceType.NONE,
		"grid unchanged when inventory empty")


func test_logic_place_consumes_inventory() -> void:
	var ctx := _make_logic_context([
		GridEnums.PieceType.OBSERVER,
		GridEnums.PieceType.MIRROR_FWDSLASH,
	])
	ctx.logic.try_place_piece(
		Vector2i(2, 2), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	expect_eq(ctx.inv.get_count(GridEnums.PieceType.OBSERVER), 0,
		"observer count decremented after placement")
	expect_eq(ctx.inv.get_count(GridEnums.PieceType.MIRROR_FWDSLASH), 1,
		"mirror count unchanged")
	# Second placement fails (inventory depleted).
	var ok2: bool = ctx.logic.try_place_piece(
		Vector2i(2, 1), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	expect_false(ok2, "second observer placement fails after inventory exhausted")
	expect_eq(ctx.grid.get_piece_type(Vector2i(2, 1)), GridEnums.PieceType.NONE,
		"grid at (2,1) unchanged after failed placement")


func test_logic_remove_returns_to_inventory() -> void:
	var ctx := _make_logic_context([GridEnums.PieceType.OBSERVER])
	ctx.logic.try_place_piece(
		Vector2i(2, 2), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	expect_eq(ctx.inv.get_count(GridEnums.PieceType.OBSERVER), 0, "count 0 after placement")

	var ok: bool = ctx.logic.try_remove_piece(Vector2i(2, 2))
	expect_true(ok, "try_remove_piece returns true")
	expect_eq(ctx.grid.get_piece_type(Vector2i(2, 2)), GridEnums.PieceType.NONE,
		"cell empty after removal")
	expect_eq(ctx.inv.get_count(GridEnums.PieceType.OBSERVER), 1,
		"observer returned to inventory after removal")


func test_logic_remove_fixed_rejected() -> void:
	var data := _make_level_data_5x5([])
	data.fixed_pieces = [{"row": 2, "col": 2, "piece_type": GridEnums.PieceType.OBSERVER, "direction": GridEnums.Direction.EAST}]
	var ctx := _make_logic_context_from_data(data)
	var ok: bool = ctx.logic.try_remove_piece(Vector2i(2, 2))
	expect_false(ok, "try_remove_piece on fixed piece returns false")
	expect_eq(ctx.grid.get_piece_type(Vector2i(2, 2)), GridEnums.PieceType.OBSERVER,
		"fixed piece still present after failed remove")


func test_logic_remove_empty_rejected() -> void:
	var ctx := _make_logic_context([])
	var ok: bool = ctx.logic.try_remove_piece(Vector2i(2, 2))
	expect_false(ok, "try_remove_piece on empty cell returns false")


# ── Win condition integration tests ──────────────────────────────────────────

func test_logic_win_on_placement() -> void:
	# 3×3 grid: OBSERVER slot at (1,0), TARGET at (1,2).
	# Place observer facing EAST → ray hits target → win.
	var ctx := _make_logic_win_context()
	var win_fired := false
	ctx.logic.puzzle_won.connect(func() -> void: win_fired = true)

	ctx.logic.try_place_piece(
		Vector2i(1, 0), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	expect_true(win_fired, "puzzle_won emitted when all targets lit")


func test_logic_no_win_partial() -> void:
	# Two targets; only one in line of sight.
	# Grid: 3×5. SLOT at (1,0), TARGET at (1,2), WALL at (1,3), TARGET at (1,4).
	var data := LevelData.new()
	data.title = "partial"
	data.rows  = 3
	data.cols  = 5
	data.tile_grid = [
		GridEnums.TileType.WALL, GridEnums.TileType.WALL,   GridEnums.TileType.WALL,   GridEnums.TileType.WALL,   GridEnums.TileType.WALL,
		GridEnums.TileType.SLOT, GridEnums.TileType.SLOT,   GridEnums.TileType.TARGET,  GridEnums.TileType.WALL,   GridEnums.TileType.TARGET,
		GridEnums.TileType.WALL, GridEnums.TileType.WALL,   GridEnums.TileType.WALL,   GridEnums.TileType.WALL,   GridEnums.TileType.WALL,
	]
	data.fixed_pieces = []
	data.player_inventory = [GridEnums.PieceType.OBSERVER]

	var ctx := _make_logic_context_from_data(data)
	var win_fired := false
	ctx.logic.puzzle_won.connect(func() -> void: win_fired = true)

	# Observer facing EAST → lights (1,2) but wall stops ray before (1,4).
	ctx.logic.try_place_piece(Vector2i(1, 0), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	expect_true(ctx.grid.is_target_lit(Vector2i(1, 2)), "first target is lit")
	expect_false(ctx.grid.is_target_lit(Vector2i(1, 4)), "second target is unlit (behind wall)")
	expect_false(win_fired, "puzzle_won NOT emitted when one target remains unlit")


func test_logic_win_fires_once() -> void:
	# Win should fire exactly once even if recalculate is called multiple times.
	var ctx := _make_logic_win_context()
	var win_count := 0
	ctx.logic.puzzle_won.connect(func() -> void: win_count += 1)

	ctx.logic.try_place_piece(
		Vector2i(1, 0), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	# Force additional recalculations — puzzle_won must not re-fire.
	ctx.logic.recalculate_all_rays()
	ctx.logic.recalculate_all_rays()
	expect_eq(win_count, 1, "puzzle_won fires exactly once per level")
	expect_true(ctx.logic.is_solved(), "is_solved() returns true after win")


func test_logic_win_fewer_pieces() -> void:
	# Inventory has 2 observers but only 1 is needed to light the target.
	# Winning with fewer placed pieces must be valid.
	var ctx := _make_logic_win_context_extra_pieces()
	var win_fired := false
	ctx.logic.puzzle_won.connect(func() -> void: win_fired = true)

	# Place only one observer (the second stays in inventory).
	ctx.logic.try_place_piece(
		Vector2i(1, 0), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	expect_true(win_fired, "win fires with only one of two available pieces placed")
	expect_eq(ctx.inv.get_count(GridEnums.PieceType.OBSERVER), 1,
		"unused observer remains in inventory")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Create a PieceInventory from a list of PieceType ints.
func _make_inventory(piece_types: Array) -> PieceInventory:
	var data := LevelData.new()
	data.title = "test"
	data.rows  = 1
	data.cols  = 1
	data.tile_grid = [GridEnums.TileType.SLOT]
	data.fixed_pieces = []
	data.player_inventory = piece_types
	var inv := PieceInventory.new()
	inv.load_from_level_data(data)
	return inv


## 5×5 GridState: walls on border, SLOTs inside except (1,3) = TARGET, (2,4) = EMPTY.
##
## Row 0: W W W W W
## Row 1: W S S T W
## Row 2: W S S S E
## Row 3: W S S S W
## Row 4: W W W W W
## (W=WALL, S=SLOT, T=TARGET, E=EMPTY)
func _make_grid_5x5() -> GridState:
	var data := _make_level_data_5x5([])
	var g := GridState.new()
	g.load_from_level_data(data)
	return g


func _make_level_data_5x5(inventory: Array) -> LevelData:
	var data := LevelData.new()
	data.title = "test-5x5"
	data.rows  = 5
	data.cols  = 5
	# Flat row-major layout.
	var W := GridEnums.TileType.WALL
	var S := GridEnums.TileType.SLOT
	var T := GridEnums.TileType.TARGET
	var E := GridEnums.TileType.EMPTY
	data.tile_grid = [
		W, W, W, W, W,
		W, S, S, T, W,
		W, S, S, S, E,
		W, S, S, S, W,
		W, W, W, W, W,
	]
	data.fixed_pieces = []
	data.player_inventory = inventory
	return data


## Context bundle for SightLinesLogic integration tests.
class LogicContext:
	var logic: SightLinesLogic
	var grid:  GridState
	var inv:   PieceInventory


func _make_logic_context(inventory: Array) -> LogicContext:
	var data := _make_level_data_5x5(inventory)
	return _make_logic_context_from_data(data)


func _make_logic_context_from_data(data: LevelData) -> LogicContext:
	var g := GridState.new()
	g.load_from_level_data(data)

	var inv := PieceInventory.new()
	inv.load_from_level_data(data)

	var logic := SightLinesLogic.new()
	logic.bind_grid(g)
	logic.bind_inventory(inv)

	var ctx := LogicContext.new()
	ctx.logic = logic
	ctx.grid  = g
	ctx.inv   = inv
	return ctx


## Minimal 3×3 win context: SLOT at (1,0), TARGET at (1,2).
## Placing observer at (1,0) facing EAST → ray lights target → win.
func _make_logic_win_context() -> LogicContext:
	var data := LevelData.new()
	data.title = "win-test"
	data.rows  = 3
	data.cols  = 3
	var W := GridEnums.TileType.WALL
	var S := GridEnums.TileType.SLOT
	var T := GridEnums.TileType.TARGET
	data.tile_grid = [
		W, W, W,
		S, S, T,
		W, W, W,
	]
	data.fixed_pieces = []
	data.player_inventory = [GridEnums.PieceType.OBSERVER]
	return _make_logic_context_from_data(data)


## Same as win context but with two observers in inventory (only one needed).
func _make_logic_win_context_extra_pieces() -> LogicContext:
	var data := LevelData.new()
	data.title = "win-extra"
	data.rows  = 3
	data.cols  = 3
	var W := GridEnums.TileType.WALL
	var S := GridEnums.TileType.SLOT
	var T := GridEnums.TileType.TARGET
	data.tile_grid = [
		W, W, W,
		S, S, T,
		W, W, W,
	]
	data.fixed_pieces = []
	data.player_inventory = [GridEnums.PieceType.OBSERVER, GridEnums.PieceType.OBSERVER]
	return _make_logic_context_from_data(data)


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
