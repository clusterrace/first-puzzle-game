# TestInputController.gd — Unit tests for KAMA-18 input handling.
#
# Run headless: godot --headless --script tests/TestInputController.gd
#
# Covers all KAMA-18 acceptance criteria:
#   - State machine: IDLE / PIECE_SELECTED / LOCKED transitions
#   - select_piece_type() validates inventory before entering PIECE_SELECTED
#   - Left-click on empty SLOT places selected piece and returns to IDLE
#   - Placement rejected when cell is occupied or not a SLOT
#   - Left-click on placed observer → RotatePieceCommand (rotate CW)
#   - Left-click on placed mirror   → ToggleMirrorCommand (toggle / ↔ \)
#   - Right-click on placed non-fixed piece → RemovePieceCommand (pick up)
#   - Right-click on fixed piece → no action
#   - Z key (puzzle_undo) → undo reverses last action and updates inventory
#   - R key (puzzle_reset) → grid and inventory restored to initial state
#   - Escape (puzzle_deselect) → returns PIECE_SELECTED → IDLE
#   - puzzle_won locks all input
#   - ToggleMirrorCommand: execute / undo are self-inverse
#   - PlacePieceCommand: inventory consumed on execute, returned on undo
#   - RemovePieceCommand: inventory returned on execute, consumed on undo

extends SceneTree


# ── Test runner ───────────────────────────────────────────────────────────────

var _pass_count: int = 0
var _fail_count: int = 0
var _current_suite: String = ""


func _init() -> void:
	print("\n=== TestInputController ===\n")

	# ToggleMirrorCommand
	suite("ToggleMirrorCommand — execute toggles FWDSLASH to BKSLASH")
	test_toggle_fwd_to_bk()

	suite("ToggleMirrorCommand — execute toggles BKSLASH to FWDSLASH")
	test_toggle_bk_to_fwd()

	suite("ToggleMirrorCommand — undo restores original orientation")
	test_toggle_undo()

	suite("ToggleMirrorCommand — execute rejects non-mirror piece")
	test_toggle_rejects_observer()

	suite("ToggleMirrorCommand — execute rejects fixed mirror")
	test_toggle_rejects_fixed()

	# GridState.toggle_mirror_orientation
	suite("GridState.toggle_mirror_orientation — out-of-bounds returns false")
	test_toggle_mirror_oob()

	# PlacePieceCommand + inventory
	suite("PlacePieceCommand — execute consumes inventory")
	test_place_consumes_inventory()

	suite("PlacePieceCommand — execute rejected when inventory empty")
	test_place_rejected_no_inventory()

	suite("PlacePieceCommand — undo returns piece to inventory")
	test_place_undo_returns_inventory()

	# RemovePieceCommand + inventory
	suite("RemovePieceCommand — execute returns piece to inventory")
	test_remove_returns_inventory()

	suite("RemovePieceCommand — undo consumes from inventory")
	test_remove_undo_consumes_inventory()

	# InputController state machine
	suite("InputController — initial state is IDLE")
	test_controller_initial_state()

	suite("InputController — select_piece_type transitions to PIECE_SELECTED")
	test_controller_select_transitions()

	suite("InputController — select_piece_type blocked when inventory empty")
	test_controller_select_blocked_no_inventory()

	suite("InputController — deselect_piece returns to IDLE")
	test_controller_deselect()

	suite("InputController — place via _try_place: success returns to IDLE")
	test_controller_place_success()

	suite("InputController — place rejected when cell occupied")
	test_controller_place_rejected_occupied()

	suite("InputController — left-click observer in IDLE rotates CW")
	test_controller_click_observer_rotates()

	suite("InputController — left-click mirror in IDLE toggles orientation")
	test_controller_click_mirror_toggles()

	suite("InputController — right-click removes placed piece")
	test_controller_right_click_removes()

	suite("InputController — right-click fixed piece does nothing")
	test_controller_right_click_fixed()

	suite("InputController — undo reverses last action")
	test_controller_undo()

	suite("InputController — undo on empty stack emits undo_unavailable")
	test_controller_undo_empty()

	suite("InputController — reset restores grid and inventory")
	test_controller_reset()

	suite("InputController — puzzle_won locks input")
	test_controller_locked_on_win()

	suite("InputController — locked: select_piece_type ignored")
	test_controller_locked_ignores_select()

	_print_summary()
	quit(1 if _fail_count > 0 else 0)


# ── Factories ─────────────────────────────────────────────────────────────────

## 4×4 grid:
##   Row 0: SLOT EMPTY SLOT  WALL
##   Row 1: EMPTY SLOT EMPTY WALL
##   Row 2: SLOT  WALL TARGET SLOT
##   Row 3: WALL  WALL WALL  WALL
## No fixed pieces.
func _make_grid() -> GridState:
	var ld: LevelData = LevelData.from_dict({
		"version": 1,
		"title": "ctrl-test",
		"rows": 4,
		"cols": 4,
		"grid": [
			[2, 0, 2, 1],
			[0, 2, 0, 1],
			[2, 1, 3, 2],
			[1, 1, 1, 1],
		],
		"fixed_pieces": [],
		"player_inventory": [],
	})
	var g := GridState.new()
	g.load_from_level_data(ld)
	return g


## Grid with one fixed OBSERVER at (0,0) facing EAST.
func _make_grid_with_fixed() -> GridState:
	var ld: LevelData = LevelData.from_dict({
		"version": 1,
		"title": "ctrl-test-fixed",
		"rows": 4,
		"cols": 4,
		"grid": [
			[2, 0, 2, 1],
			[0, 2, 0, 1],
			[2, 1, 3, 2],
			[1, 1, 1, 1],
		],
		"fixed_pieces": [
			{"row": 0, "col": 0, "piece_type": 1, "direction": 1},
		],
		"player_inventory": [],
	})
	var g := GridState.new()
	g.load_from_level_data(ld)
	return g


## LevelData with 1 OBSERVER + 1 MIRROR_FWDSLASH in inventory.
func _make_level_data_with_inv() -> LevelData:
	return LevelData.from_dict({
		"version": 1,
		"title": "ctrl-test-inv",
		"rows": 4,
		"cols": 4,
		"grid": [
			[2, 0, 2, 1],
			[0, 2, 0, 1],
			[2, 1, 3, 2],
			[1, 1, 1, 1],
		],
		"fixed_pieces": [],
		"player_inventory": [1, 2],  # 1 OBSERVER, 1 MIRROR_FWDSLASH
	})


## Returns a SightLinesLogic bound to [param grid] with no inventory.
func _make_logic(grid: GridState) -> SightLinesLogic:
	var logic := SightLinesLogic.new()
	logic.bind_grid(grid)
	return logic


## Returns a fully set-up InputController bound to all systems.
func _make_controller(
		grid: GridState,
		logic: SightLinesLogic,
		inv: PieceInventory,
		level_data: LevelData) -> InputController:
	var history := CommandHistory.new()
	history.initialize(grid, grid.get_piece_snapshot())
	var ctrl := InputController.new()
	ctrl.setup(grid, logic, history, inv, level_data)
	return ctrl


# ── ToggleMirrorCommand tests ─────────────────────────────────────────────────

func test_toggle_fwd_to_bk() -> void:
	var g := _make_grid()
	g.place_piece(Vector2i(0, 0), GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.Direction.NORTH)
	var cmd := ToggleMirrorCommand.new(g, 0, 0)
	var ok: bool = cmd.execute()
	expect_true(ok, "execute() returns true for a FWDSLASH mirror")
	expect_eq(g.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.MIRROR_BKSLASH,
		"piece_type is MIRROR_BKSLASH after toggle")


func test_toggle_bk_to_fwd() -> void:
	var g := _make_grid()
	g.place_piece(Vector2i(0, 0), GridEnums.PieceType.MIRROR_BKSLASH, GridEnums.Direction.NORTH)
	var cmd := ToggleMirrorCommand.new(g, 0, 0)
	cmd.execute()
	expect_eq(g.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.MIRROR_FWDSLASH,
		"BKSLASH toggles to FWDSLASH")


func test_toggle_undo() -> void:
	var g := _make_grid()
	g.place_piece(Vector2i(0, 0), GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.Direction.NORTH)
	var cmd := ToggleMirrorCommand.new(g, 0, 0)
	cmd.execute()  # FWDSLASH → BKSLASH
	cmd.undo()     # BKSLASH → FWDSLASH
	expect_eq(g.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.MIRROR_FWDSLASH,
		"undo restores original FWDSLASH orientation")


func test_toggle_rejects_observer() -> void:
	var g := _make_grid()
	g.place_piece(Vector2i(0, 0), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	var cmd := ToggleMirrorCommand.new(g, 0, 0)
	var ok: bool = cmd.execute()
	expect_false(ok, "execute() returns false for OBSERVER piece")
	expect_eq(g.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.OBSERVER,
		"piece_type unchanged after rejected toggle")


func test_toggle_rejects_fixed() -> void:
	var g := _make_grid_with_fixed()
	# Override (0,0) piece type manually for testing a fixed mirror scenario.
	# Use a fresh grid with a fixed mirror instead.
	var ld: LevelData = LevelData.from_dict({
		"version": 1,
		"title": "fixed-mirror",
		"rows": 3,
		"cols": 3,
		"grid": [[2, 0, 0], [0, 0, 0], [0, 0, 0]],
		"fixed_pieces": [{"row": 0, "col": 0, "piece_type": 2, "direction": 0}],
		"player_inventory": [],
	})
	var g2 := GridState.new()
	g2.load_from_level_data(ld)
	var cmd := ToggleMirrorCommand.new(g2, 0, 0)
	var ok: bool = cmd.execute()
	expect_false(ok, "execute() returns false for a fixed mirror")
	expect_eq(g2.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.MIRROR_FWDSLASH,
		"fixed mirror unchanged after rejected toggle")


func test_toggle_mirror_oob() -> void:
	var g := _make_grid()
	var ok: bool = g.toggle_mirror_orientation(Vector2i(99, 99))
	expect_false(ok, "toggle_mirror_orientation returns false for out-of-bounds")


# ── PlacePieceCommand + inventory tests ───────────────────────────────────────

func test_place_consumes_inventory() -> void:
	var g := _make_grid()
	var inv := PieceInventory.new()
	inv.load_from_level_data(_make_level_data_with_inv())
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 1, "inventory starts with 1 OBSERVER")

	var cmd := PlacePieceCommand.new(
		g, 0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST, inv)
	var ok: bool = cmd.execute()
	expect_true(ok, "execute() returns true")
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 0, "OBSERVER consumed from inventory")


func test_place_rejected_no_inventory() -> void:
	var g := _make_grid()
	var inv := PieceInventory.new()
	# No pieces loaded — empty inventory.
	var cmd := PlacePieceCommand.new(
		g, 0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST, inv)
	var ok: bool = cmd.execute()
	expect_false(ok, "execute() rejected when inventory is empty")
	expect_eq(g.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.NONE,
		"grid unchanged after rejected placement")


func test_place_undo_returns_inventory() -> void:
	var g := _make_grid()
	var inv := PieceInventory.new()
	inv.load_from_level_data(_make_level_data_with_inv())
	var cmd := PlacePieceCommand.new(
		g, 0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST, inv)
	cmd.execute()
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 0, "consumed after execute")
	cmd.undo()
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 1, "returned after undo")
	expect_eq(g.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.NONE,
		"grid cell empty after undo")


# ── RemovePieceCommand + inventory tests ──────────────────────────────────────

func test_remove_returns_inventory() -> void:
	var g := _make_grid()
	var inv := PieceInventory.new()
	inv.load_from_level_data(_make_level_data_with_inv())
	# Consume observer by placing it.
	inv.consume(GridEnums.PieceType.OBSERVER)
	g.place_piece(Vector2i(0, 0), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 0, "inventory empty before remove")

	var cmd := RemovePieceCommand.new(g, 0, 0, inv)
	var ok: bool = cmd.execute()
	expect_true(ok, "execute() returns true")
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 1, "piece returned to inventory")
	expect_eq(g.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.NONE,
		"grid cell empty after remove")


func test_remove_undo_consumes_inventory() -> void:
	var g := _make_grid()
	var inv := PieceInventory.new()
	inv.load_from_level_data(_make_level_data_with_inv())
	inv.consume(GridEnums.PieceType.OBSERVER)
	g.place_piece(Vector2i(0, 0), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)

	var cmd := RemovePieceCommand.new(g, 0, 0, inv)
	cmd.execute()  # piece back in inventory
	cmd.undo()     # place again, consume from inventory
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 0, "inventory consumed again after undo")
	expect_eq(g.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.OBSERVER,
		"piece back on grid after undo")


# ── InputController state machine tests ───────────────────────────────────────

func test_controller_initial_state() -> void:
	var g := _make_grid()
	var logic := _make_logic(g)
	var inv := PieceInventory.new()
	inv.load_from_level_data(_make_level_data_with_inv())
	var ctrl := _make_controller(g, logic, inv, _make_level_data_with_inv())
	expect_eq(ctrl.get_state(), InputController.State.IDLE,
		"initial state is IDLE")
	expect_eq(ctrl.get_selected_piece_type(), -1,
		"no piece selected initially")


func test_controller_select_transitions() -> void:
	var g := _make_grid()
	var logic := _make_logic(g)
	var ld := _make_level_data_with_inv()
	var inv := PieceInventory.new()
	inv.load_from_level_data(ld)
	var ctrl := _make_controller(g, logic, inv, ld)

	var selected_signals: Array[int] = []
	ctrl.piece_type_selected.connect(func(pt: int) -> void: selected_signals.append(pt))

	ctrl.select_piece_type(GridEnums.PieceType.OBSERVER)
	expect_eq(ctrl.get_state(), InputController.State.PIECE_SELECTED,
		"state is PIECE_SELECTED after select_piece_type")
	expect_eq(ctrl.get_selected_piece_type(), GridEnums.PieceType.OBSERVER,
		"selected_piece_type is OBSERVER")
	expect_eq(selected_signals.size(), 1, "piece_type_selected signal emitted once")
	expect_eq(selected_signals[0], GridEnums.PieceType.OBSERVER,
		"signal carries correct piece type")


func test_controller_select_blocked_no_inventory() -> void:
	var g := _make_grid()
	var logic := _make_logic(g)
	var inv := PieceInventory.new()
	# Empty inventory — no pieces available.
	var ctrl := _make_controller(g, logic, inv, _make_level_data_with_inv())

	ctrl.select_piece_type(GridEnums.PieceType.OBSERVER)
	expect_eq(ctrl.get_state(), InputController.State.IDLE,
		"state remains IDLE when inventory has no OBSERVER")


func test_controller_deselect() -> void:
	var g := _make_grid()
	var logic := _make_logic(g)
	var ld := _make_level_data_with_inv()
	var inv := PieceInventory.new()
	inv.load_from_level_data(ld)
	var ctrl := _make_controller(g, logic, inv, ld)

	var deselect_count: int = 0
	ctrl.piece_deselected.connect(func() -> void: deselect_count += 1)

	ctrl.select_piece_type(GridEnums.PieceType.OBSERVER)
	ctrl.deselect_piece()
	expect_eq(ctrl.get_state(), InputController.State.IDLE, "state is IDLE after deselect")
	expect_eq(ctrl.get_selected_piece_type(), -1, "no piece selected after deselect")
	expect_eq(deselect_count, 1, "piece_deselected signal emitted once")


func test_controller_place_success() -> void:
	var g := _make_grid()
	var logic := _make_logic(g)
	var ld := _make_level_data_with_inv()
	var inv := PieceInventory.new()
	inv.load_from_level_data(ld)
	var ctrl := _make_controller(g, logic, inv, ld)

	ctrl.select_piece_type(GridEnums.PieceType.OBSERVER)
	ctrl._try_place(Vector2i(0, 0))  # Direct API call (avoids needing scene)

	expect_eq(ctrl.get_state(), InputController.State.IDLE, "returns to IDLE after placing")
	expect_eq(g.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.OBSERVER,
		"OBSERVER placed on grid")
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 0, "inventory consumed")


func test_controller_place_rejected_occupied() -> void:
	var g := _make_grid()
	g.place_piece(Vector2i(0, 0), GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.Direction.NORTH)
	var logic := _make_logic(g)
	var ld := _make_level_data_with_inv()
	var inv := PieceInventory.new()
	inv.load_from_level_data(ld)
	var ctrl := _make_controller(g, logic, inv, ld)

	var rejected: bool = false
	ctrl.placement_rejected.connect(func() -> void: rejected = true)

	ctrl.select_piece_type(GridEnums.PieceType.OBSERVER)
	ctrl._try_place(Vector2i(0, 0))  # Cell is already occupied.

	expect_true(rejected, "placement_rejected signal emitted")
	expect_eq(ctrl.get_state(), InputController.State.PIECE_SELECTED,
		"remains PIECE_SELECTED after rejection")
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 1,
		"inventory NOT consumed after rejection")


func test_controller_click_observer_rotates() -> void:
	var g := _make_grid()
	g.place_piece(Vector2i(0, 0), GridEnums.PieceType.OBSERVER, GridEnums.Direction.NORTH)
	var logic := _make_logic(g)
	var inv := PieceInventory.new()
	var ctrl := _make_controller(g, logic, inv, _make_level_data_with_inv())

	ctrl._try_interact(Vector2i(0, 0))
	expect_eq(g.get_piece_direction(Vector2i(0, 0)), GridEnums.Direction.EAST,
		"OBSERVER rotated NORTH → EAST (CW)")


func test_controller_click_mirror_toggles() -> void:
	var g := _make_grid()
	g.place_piece(Vector2i(0, 0), GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.Direction.NORTH)
	var logic := _make_logic(g)
	var inv := PieceInventory.new()
	var ctrl := _make_controller(g, logic, inv, _make_level_data_with_inv())

	ctrl._try_interact(Vector2i(0, 0))
	expect_eq(g.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.MIRROR_BKSLASH,
		"FWDSLASH toggled to BKSLASH on click")


func test_controller_right_click_removes() -> void:
	var g := _make_grid()
	g.place_piece(Vector2i(0, 0), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	var logic := _make_logic(g)
	var ld := _make_level_data_with_inv()
	var inv := PieceInventory.new()
	inv.load_from_level_data(ld)
	inv.consume(GridEnums.PieceType.OBSERVER)  # Reflect that it was placed.
	var ctrl := _make_controller(g, logic, inv, ld)

	ctrl._handle_right_click(Vector2i(0, 0))
	expect_eq(g.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.NONE,
		"piece removed from grid by right-click")
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 1,
		"piece returned to inventory on right-click remove")


func test_controller_right_click_fixed() -> void:
	var g := _make_grid_with_fixed()
	var logic := _make_logic(g)
	var inv := PieceInventory.new()
	var ctrl := _make_controller(g, logic, inv, _make_level_data_with_inv())

	ctrl._handle_right_click(Vector2i(0, 0))  # (0,0) is fixed OBSERVER
	expect_eq(g.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.OBSERVER,
		"fixed piece not removed by right-click")


func test_controller_undo() -> void:
	var g := _make_grid()
	var logic := _make_logic(g)
	var ld := _make_level_data_with_inv()
	var inv := PieceInventory.new()
	inv.load_from_level_data(ld)
	var ctrl := _make_controller(g, logic, inv, ld)

	ctrl.select_piece_type(GridEnums.PieceType.OBSERVER)
	ctrl._try_place(Vector2i(0, 0))
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 0, "consumed after place")

	ctrl._handle_undo()
	expect_eq(g.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.NONE,
		"piece removed from grid after undo")
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 1,
		"inventory restored after undo")


func test_controller_undo_empty() -> void:
	var g := _make_grid()
	var logic := _make_logic(g)
	var inv := PieceInventory.new()
	var ctrl := _make_controller(g, logic, inv, _make_level_data_with_inv())

	var unavailable_count: int = 0
	ctrl.undo_unavailable.connect(func() -> void: unavailable_count += 1)

	ctrl._handle_undo()
	expect_eq(unavailable_count, 1, "undo_unavailable signal emitted on empty stack")


func test_controller_reset() -> void:
	var g := _make_grid()
	var logic := _make_logic(g)
	var ld := _make_level_data_with_inv()
	var inv := PieceInventory.new()
	inv.load_from_level_data(ld)
	var ctrl := _make_controller(g, logic, inv, ld)

	# Place pieces.
	ctrl.select_piece_type(GridEnums.PieceType.OBSERVER)
	ctrl._try_place(Vector2i(0, 0))
	ctrl.select_piece_type(GridEnums.PieceType.MIRROR_FWDSLASH)
	ctrl._try_place(Vector2i(0, 2))
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 0, "OBSERVER consumed")
	expect_eq(inv.get_count(GridEnums.PieceType.MIRROR_FWDSLASH), 0, "MIRROR consumed")

	ctrl._handle_reset()

	# Grid cleared.
	expect_eq(g.get_piece_type(Vector2i(0, 0)), GridEnums.PieceType.NONE,
		"OBSERVER removed from grid after reset")
	expect_eq(g.get_piece_type(Vector2i(0, 2)), GridEnums.PieceType.NONE,
		"MIRROR removed from grid after reset")
	# Inventory restored.
	expect_eq(inv.get_count(GridEnums.PieceType.OBSERVER), 1,
		"OBSERVER count restored after reset")
	expect_eq(inv.get_count(GridEnums.PieceType.MIRROR_FWDSLASH), 1,
		"MIRROR count restored after reset")
	# Controller back to IDLE.
	expect_eq(ctrl.get_state(), InputController.State.IDLE,
		"state is IDLE after reset")


func test_controller_locked_on_win() -> void:
	var g := _make_grid()
	var logic := _make_logic(g)
	var inv := PieceInventory.new()
	var ctrl := _make_controller(g, logic, inv, _make_level_data_with_inv())

	var locked_count: int = 0
	ctrl.input_locked.connect(func() -> void: locked_count += 1)

	# Manually fire puzzle_won to simulate win condition.
	logic.puzzle_won.emit()

	expect_eq(ctrl.get_state(), InputController.State.LOCKED,
		"state is LOCKED after puzzle_won")
	expect_eq(locked_count, 1, "input_locked signal emitted")


func test_controller_locked_ignores_select() -> void:
	var g := _make_grid()
	var logic := _make_logic(g)
	var ld := _make_level_data_with_inv()
	var inv := PieceInventory.new()
	inv.load_from_level_data(ld)
	var ctrl := _make_controller(g, logic, inv, ld)

	logic.puzzle_won.emit()  # Lock the controller.
	ctrl.select_piece_type(GridEnums.PieceType.OBSERVER)

	expect_eq(ctrl.get_state(), InputController.State.LOCKED,
		"state stays LOCKED when select_piece_type called")
	expect_eq(ctrl.get_selected_piece_type(), -1,
		"no piece selected while LOCKED")


# ── Assertion helpers ─────────────────────────────────────────────────────────

func suite(name: String) -> void:
	_current_suite = name


func expect_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		_pass("[PASS] %s: %s" % [_current_suite, label])
	else:
		_fail("[FAIL] %s: %s\n       expected: %s\n       got:      %s" % [
			_current_suite, label, str(expected), str(actual)])


func expect_true(value: bool, label: String) -> void:
	if value:
		_pass("[PASS] %s: %s" % [_current_suite, label])
	else:
		_fail("[FAIL] %s: %s (expected true)" % [_current_suite, label])


func expect_false(value: bool, label: String) -> void:
	if not value:
		_pass("[PASS] %s: %s" % [_current_suite, label])
	else:
		_fail("[FAIL] %s: %s (expected false)" % [_current_suite, label])


func _pass(msg: String) -> void:
	print(msg)
	_pass_count += 1


func _fail(msg: String) -> void:
	printerr(msg)
	_fail_count += 1


func _print_summary() -> void:
	print("\n─────────────────────────────────")
	print("Results: %d passed, %d failed" % [_pass_count, _fail_count])
	if _fail_count == 0:
		print("All tests passed.")
	else:
		printerr("%d test(s) FAILED." % _fail_count)
	print("─────────────────────────────────\n")
