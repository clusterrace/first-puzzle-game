# TestCommandHistory.gd — Unit tests for the KAMA-15 command-pattern undo/reset system.
#
# Run headless: godot --headless --script tests/TestCommandHistory.gd
#
# Covers all KAMA-15 acceptance criteria:
#   - PlacePieceCommand: execute places piece, undo removes it
#   - RotatePieceCommand: execute rotates CW, undo restores original direction
#   - RemovePieceCommand: execute removes piece, undo places it back
#   - CommandHistory.push(): executes command and records it
#   - CommandHistory.undo(): reverses most recent action
#   - CommandHistory.undo() on empty stack returns false
#   - Multiple undos unwind to initial state
#   - CommandHistory.reset(): restores initial snapshot, clears stack
#   - can_undo() reflects stack state accurately
#   - undo_available_changed signal fires on state transitions
#   - max_history_size cap evicts oldest entry

extends SceneTree


# ── Test runner ───────────────────────────────────────────────────────────────

var _pass_count: int = 0
var _fail_count: int = 0
var _current_suite: String = ""


func _init() -> void:
	print("\n=== TestCommandHistory ===\n")

	suite("PlacePieceCommand — execute")
	test_place_execute()

	suite("PlacePieceCommand — undo")
	test_place_undo()

	suite("PlacePieceCommand — execute rejects non-SLOT")
	test_place_rejects_occupied()

	suite("RotatePieceCommand — execute")
	test_rotate_execute()

	suite("RotatePieceCommand — undo restores original direction")
	test_rotate_undo()

	suite("RotatePieceCommand — execute rejects fixed piece")
	test_rotate_rejects_fixed()

	suite("RemovePieceCommand — execute")
	test_remove_execute()

	suite("RemovePieceCommand — undo restores piece and direction")
	test_remove_undo()

	suite("RemovePieceCommand — execute rejects fixed piece")
	test_remove_rejects_fixed()

	suite("CommandHistory — push records successful commands")
	test_history_push()

	suite("CommandHistory — undo pops and reverses last command")
	test_history_undo_single()

	suite("CommandHistory — undo returns false on empty stack")
	test_history_undo_empty()

	suite("CommandHistory — can_undo() tracks stack state")
	test_history_can_undo()

	suite("CommandHistory — multiple undos unwind to initial state")
	test_history_multiple_undo()

	suite("CommandHistory — reset restores initial snapshot")
	test_history_reset()

	suite("CommandHistory — reset clears stack and emits signal")
	test_history_reset_clears_stack()

	suite("CommandHistory — undo_available_changed signal fires correctly")
	test_history_signal()

	suite("CommandHistory — max_history_size evicts oldest entry")
	test_history_max_size()

	suite("CommandHistory — push discards failed commands")
	test_history_push_failure()

	_print_summary()
	quit(1 if _fail_count > 0 else 0)


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns a minimal GridState loaded from an inline level dict.
## Layout (3×3):
##   [SLOT, EMPTY, SLOT]
##   [EMPTY, SLOT, EMPTY]
##   [SLOT, EMPTY, SLOT]
## Corner slots: (0,0), (0,2), (1,1), (2,0), (2,2).
## No fixed pieces, no targets.
func _make_grid() -> GridState:
	var ld: LevelData = LevelData.from_dict({
		"version": 1,
		"title": "test",
		"rows": 3,
		"cols": 3,
		"grid": [
			[2, 0, 2],
			[0, 2, 0],
			[2, 0, 2],
		],
		"fixed_pieces": [],
		"player_inventory": [],
	})
	var g := GridState.new()
	g.load_from_level_data(ld)
	return g


## Returns a GridState that has one pre-placed fixed OBSERVER at (0,0) facing EAST.
func _make_grid_with_fixed() -> GridState:
	var ld: LevelData = LevelData.from_dict({
		"version": 1,
		"title": "test-fixed",
		"rows": 3,
		"cols": 3,
		"grid": [
			[2, 0, 2],
			[0, 2, 0],
			[2, 0, 2],
		],
		"fixed_pieces": [
			{"row": 0, "col": 0, "piece_type": 1, "direction": 1},
		],
		"player_inventory": [],
	})
	var g := GridState.new()
	g.load_from_level_data(ld)
	return g


## Returns a fresh CommandHistory initialised with an empty snapshot.
func _make_history(grid: GridState) -> CommandHistory:
	var h := CommandHistory.new()
	h.initialize(grid, grid.get_piece_snapshot())
	return h


# ── PlacePieceCommand ─────────────────────────────────────────────────────────

func test_place_execute() -> void:
	var g := _make_grid()
	var cmd := PlacePieceCommand.new(
		g, 0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	var ok: bool = cmd.execute()
	expect_true(ok, "execute() returns true for empty SLOT")
	expect_eq(g.get_piece_type(0, 0), GridEnums.PieceType.OBSERVER,
		"piece_type is OBSERVER after execute()")
	expect_eq(g.get_piece_direction(0, 0), GridEnums.Direction.EAST,
		"piece_direction is EAST after execute()")


func test_place_undo() -> void:
	var g := _make_grid()
	var cmd := PlacePieceCommand.new(
		g, 0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.NORTH)
	cmd.execute()
	cmd.undo()
	expect_eq(g.get_piece_type(0, 0), GridEnums.PieceType.NONE,
		"cell is empty after undo()")
	expect_true(g.is_placeable(0, 0), "cell is placeable again after undo()")


func test_place_rejects_occupied() -> void:
	var g := _make_grid()
	# Place the first piece.
	var cmd1 := PlacePieceCommand.new(
		g, 0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	cmd1.execute()
	# Attempt to place again on the same (now occupied) cell.
	var cmd2 := PlacePieceCommand.new(
		g, 0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.SOUTH)
	var ok: bool = cmd2.execute()
	expect_false(ok, "execute() returns false when cell is already occupied")
	expect_eq(g.get_piece_direction(0, 0), GridEnums.Direction.EAST,
		"original piece direction unchanged after rejected placement")


# ── RotatePieceCommand ────────────────────────────────────────────────────────

func test_rotate_execute() -> void:
	var g := _make_grid()
	# Place OBSERVER facing EAST, then rotate CW → should face SOUTH.
	g.place_piece(0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	var cmd := RotatePieceCommand.new(g, 0, 0)
	var ok: bool = cmd.execute()
	expect_true(ok, "execute() returns true for a rotatable piece")
	expect_eq(g.get_piece_direction(0, 0), GridEnums.Direction.SOUTH,
		"direction is SOUTH (CW from EAST) after execute()")


func test_rotate_undo() -> void:
	var g := _make_grid()
	g.place_piece(0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
	var cmd := RotatePieceCommand.new(g, 0, 0)
	cmd.execute()  # EAST → SOUTH
	cmd.undo()     # SOUTH → WEST → NORTH → EAST (3 × CW)
	expect_eq(g.get_piece_direction(0, 0), GridEnums.Direction.EAST,
		"direction restored to EAST after undo()")


func test_rotate_rejects_fixed() -> void:
	var g := _make_grid_with_fixed()
	var cmd := RotatePieceCommand.new(g, 0, 0)
	var ok: bool = cmd.execute()
	expect_false(ok, "execute() returns false for a fixed piece")


# ── RemovePieceCommand ────────────────────────────────────────────────────────

func test_remove_execute() -> void:
	var g := _make_grid()
	g.place_piece(0, 0, GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.Direction.NORTH)
	var cmd := RemovePieceCommand.new(g, 0, 0)
	var ok: bool = cmd.execute()
	expect_true(ok, "execute() returns true for a removable piece")
	expect_eq(g.get_piece_type(0, 0), GridEnums.PieceType.NONE,
		"cell is empty after execute()")


func test_remove_undo() -> void:
	var g := _make_grid()
	g.place_piece(0, 0, GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.Direction.WEST)
	var cmd := RemovePieceCommand.new(g, 0, 0)
	cmd.execute()
	cmd.undo()
	expect_eq(g.get_piece_type(0, 0), GridEnums.PieceType.MIRROR_FWDSLASH,
		"piece type restored after undo()")
	expect_eq(g.get_piece_direction(0, 0), GridEnums.Direction.WEST,
		"piece direction restored after undo()")


func test_remove_rejects_fixed() -> void:
	var g := _make_grid_with_fixed()
	var cmd := RemovePieceCommand.new(g, 0, 0)
	var ok: bool = cmd.execute()
	expect_false(ok, "execute() returns false for a fixed piece")


# ── CommandHistory ────────────────────────────────────────────────────────────

func test_history_push() -> void:
	var g := _make_grid()
	var h := _make_history(g)
	expect_false(h.can_undo(), "stack empty before push")
	h.push(PlacePieceCommand.new(
		g, 0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST))
	expect_true(h.can_undo(), "can_undo() true after successful push")
	expect_eq(h.history_size(), 1, "history_size == 1 after one push")
	expect_eq(g.get_piece_type(0, 0), GridEnums.PieceType.OBSERVER,
		"piece placed on grid after push")


func test_history_undo_single() -> void:
	var g := _make_grid()
	var h := _make_history(g)
	h.push(PlacePieceCommand.new(
		g, 0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST))
	var undone: bool = h.undo()
	expect_true(undone, "undo() returns true when stack is non-empty")
	expect_false(h.can_undo(), "stack empty after undo")
	expect_eq(g.get_piece_type(0, 0), GridEnums.PieceType.NONE,
		"piece removed from grid after undo")


func test_history_undo_empty() -> void:
	var g := _make_grid()
	var h := _make_history(g)
	var undone: bool = h.undo()
	expect_false(undone, "undo() returns false on empty stack")


func test_history_can_undo() -> void:
	var g := _make_grid()
	var h := _make_history(g)
	expect_false(h.can_undo(), "can_undo() false initially")
	h.push(PlacePieceCommand.new(
		g, 0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST))
	expect_true(h.can_undo(), "can_undo() true after push")
	h.undo()
	expect_false(h.can_undo(), "can_undo() false after undo drains stack")


func test_history_multiple_undo() -> void:
	var g := _make_grid()
	var h := _make_history(g)

	# Action 1: place OBSERVER at (0,0) EAST.
	h.push(PlacePieceCommand.new(
		g, 0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST))
	# Action 2: rotate it → SOUTH.
	h.push(RotatePieceCommand.new(g, 0, 0))
	# Action 3: place MIRROR at (0,2) NORTH.
	h.push(PlacePieceCommand.new(
		g, 0, 2, GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.Direction.NORTH))

	expect_eq(h.history_size(), 3, "3 commands on stack")

	# Undo action 3: mirror removed.
	h.undo()
	expect_eq(g.get_piece_type(0, 2), GridEnums.PieceType.NONE,
		"mirror removed after first undo")

	# Undo action 2: observer back to EAST.
	h.undo()
	expect_eq(g.get_piece_direction(0, 0), GridEnums.Direction.EAST,
		"observer direction restored to EAST after second undo")

	# Undo action 1: observer removed.
	h.undo()
	expect_eq(g.get_piece_type(0, 0), GridEnums.PieceType.NONE,
		"observer removed after third undo — board at initial state")
	expect_false(h.can_undo(), "stack empty after all undos")


func test_history_reset() -> void:
	var g := _make_grid()
	# Initial snapshot: empty (no player pieces).
	var h := _make_history(g)

	# Place two pieces.
	h.push(PlacePieceCommand.new(
		g, 0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST))
	h.push(PlacePieceCommand.new(
		g, 0, 2, GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.Direction.NORTH))

	h.reset()

	expect_eq(g.get_piece_type(0, 0), GridEnums.PieceType.NONE,
		"piece at (0,0) cleared after reset")
	expect_eq(g.get_piece_type(0, 2), GridEnums.PieceType.NONE,
		"piece at (0,2) cleared after reset")


func test_history_reset_clears_stack() -> void:
	var g := _make_grid()
	var h := _make_history(g)
	h.push(PlacePieceCommand.new(
		g, 0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST))
	expect_true(h.can_undo(), "can_undo before reset")

	var reset_fired: bool = false
	h.history_reset.connect(func() -> void: reset_fired = true)

	h.reset()
	expect_false(h.can_undo(), "stack cleared after reset")
	expect_true(reset_fired, "history_reset signal emitted")


func test_history_signal() -> void:
	var g := _make_grid()
	var h := _make_history(g)

	var signal_values: Array[bool] = []
	h.undo_available_changed.connect(func(v: bool) -> void: signal_values.append(v))

	# Push: empty → non-empty, signal fires with true.
	h.push(PlacePieceCommand.new(
		g, 0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST))
	expect_eq(signal_values.size(), 1, "signal fired once after push")
	expect_true(signal_values[0], "signal value is true after push")

	# Push a second command: non-empty → non-empty, signal must NOT fire again.
	h.push(PlacePieceCommand.new(
		g, 0, 2, GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.Direction.NORTH))
	expect_eq(signal_values.size(), 1, "signal NOT fired on second push (still non-empty)")

	# Undo first command from end: non-empty → non-empty, signal NOT fired.
	h.undo()
	expect_eq(signal_values.size(), 1, "signal NOT fired when stack still non-empty after undo")

	# Undo last command: non-empty → empty, signal fires with false.
	h.undo()
	expect_eq(signal_values.size(), 2, "signal fired when stack goes empty")
	expect_false(signal_values[1], "signal value is false when stack empty")


func test_history_max_size() -> void:
	var g := _make_grid()
	var h := CommandHistory.new()
	h.initialize(g, g.get_piece_snapshot(), 2)  # cap at 2

	h.push(PlacePieceCommand.new(
		g, 0, 0, GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST))
	h.push(RotatePieceCommand.new(g, 0, 0))       # rotate EAST → SOUTH
	# Third push exceeds cap — oldest (the placement) is dropped.
	h.push(RotatePieceCommand.new(g, 0, 0))       # rotate SOUTH → WEST

	expect_eq(h.history_size(), 2, "history_size capped at 2 after 3 pushes")

	# Undo last two (both rotations). The original placement is gone.
	h.undo()  # WEST → SOUTH (one CCW)
	h.undo()  # SOUTH → EAST (one CCW) — but first rotate was evicted
	# After eviction the bottom of the stack is the first rotate, not the place.
	# Undoing it restores from SOUTH→EAST; piece still exists on board.
	expect_eq(g.get_piece_type(0, 0), GridEnums.PieceType.OBSERVER,
		"piece still on board after undoing capped history (original place evicted)")
	expect_false(h.can_undo(), "stack empty after undoing all retained history")


func test_history_push_failure() -> void:
	var g := _make_grid()
	var h := _make_history(g)
	# Attempt to rotate an empty cell — should be rejected.
	h.push(RotatePieceCommand.new(g, 0, 0))
	expect_eq(h.history_size(), 0, "failed command not added to history")
	expect_false(h.can_undo(), "can_undo() false after failed push")


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
