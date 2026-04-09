class_name InputController
extends Node
## S3: Player input handler for Sight Lines (KAMA-18).
##
## Implements the full interaction layer for desktop mouse + keyboard:
##   - Click-to-select a piece type from inventory (via select_piece_type())
##   - Left-click empty SLOT  → place selected piece
##   - Left-click placed observer → rotate 90° CW (N→E→S→W→N)
##   - Left-click placed mirror   → toggle / ↔ \
##   - Right-click placed non-fixed piece → pick up, return to inventory
##   - Z (or puzzle_undo action)  → undo last action
##   - R (or puzzle_reset action) → reset level to initial state
##   - Escape (or puzzle_deselect action) → deselect current piece
##
## State machine:
##   IDLE           — no piece selected; grid clicks inspect/rotate/toggle/remove
##   PIECE_SELECTED — a piece type is held; next valid SLOT click places it
##   LOCKED         — puzzle solved; all input blocked
##
## Valid transitions:
##   IDLE → PIECE_SELECTED         : select_piece_type() with an available type
##   PIECE_SELECTED → IDLE         : deselect_piece() / Escape / click on occupied or invalid cell
##   PIECE_SELECTED → IDLE         : left-click empty SLOT (place succeeds)
##   IDLE → IDLE (with action)     : left-click placed observer (rotate CW)
##   IDLE → IDLE (with action)     : left-click placed mirror (toggle orientation)
##   Any  → IDLE                   : right-click placed non-fixed piece (remove)
##   Any  → current state (action) : Z / puzzle_undo (undo last command)
##   Any  → IDLE                   : R / puzzle_reset (reset level)
##   Any  → LOCKED                 : puzzle_won signal from SightLinesLogic
##
## Setup:
##   var ctrl := InputController.new()
##   add_child(ctrl)
##   ctrl.setup(grid_state, sight_lines_logic, command_history, piece_inventory, level_data)
##
## Coordinate convention: Vector2i(row, col) — pos.x = row, pos.y = col.
## Matches GridEnums.DIRECTION_DELTA.
##
## Config file: "res://config/input_controller.json"
## Keys: cell_size (float), grid_origin_x (float), grid_origin_y (float),
##       default_piece_direction (int, GridEnums.Direction).
##
## Keyboard shortcuts are checked via Godot InputMap actions first, then fall
## back to hardcoded key codes. Register actions "puzzle_undo", "puzzle_reset",
## and "puzzle_deselect" in Project Settings > Input Map to override defaults.


# ── Signals (for UI / audio layer — emit events, never drive display directly) ─

## Emitted when the player selects a piece type from inventory.
## ui-programmer: update inventory panel to show [param piece_type] as selected.
signal piece_type_selected(piece_type: int)

## Emitted when the player deselects without placing (Escape, invalid click, etc.).
## ui-programmer: clear the selection highlight in the inventory panel.
signal piece_deselected()

## Emitted when a placement attempt is rejected (no inventory, cell occupied, etc.).
## ui-programmer / ai-programmer: trigger rejection feedback (shake, sound).
signal placement_rejected()

## Emitted after any successful grid action (place, rotate, toggle, remove).
## ui-programmer: use this to refresh any state-dependent HUD elements.
signal action_performed()

## Emitted when undo is attempted but the history is empty.
signal undo_unavailable()

## Emitted when the controller locks because the puzzle was won.
signal input_locked()


# ── State machine ─────────────────────────────────────────────────────────────

enum State {
	IDLE,            ## No piece selected; grid clicks inspect or modify pieces.
	PIECE_SELECTED,  ## A piece type is held; next valid SLOT click places it.
	LOCKED,          ## Puzzle solved; all input blocked.
}

var _state: State = State.IDLE


# ── Bound systems ─────────────────────────────────────────────────────────────

var _grid: GridState           = null
var _logic: SightLinesLogic    = null
var _history: CommandHistory   = null
var _inventory: PieceInventory = null
var _level_data: LevelData     = null


# ── Config (loaded from file) ─────────────────────────────────────────────────

## Pixel side-length of one grid cell. Must match the renderer's CELL constant.
var _cell_size: float = 80.0

## Screen-space position of the top-left corner of the grid (row 0, col 0).
var _grid_origin: Vector2 = Vector2(40.0, 50.0)

## Facing direction assigned to a newly placed piece. Default: EAST.
var _default_direction: GridEnums.Direction = GridEnums.Direction.EAST


# ── Internal state ────────────────────────────────────────────────────────────

## The piece type currently selected for placement, or -1 when IDLE/LOCKED.
var _selected_piece_type: int = -1


# ── Fallback key codes (used when InputMap actions are not registered) ────────

const _KEY_UNDO:     int = KEY_Z
const _KEY_RESET:    int = KEY_R
const _KEY_DESELECT: int = KEY_ESCAPE


# ── Setup ─────────────────────────────────────────────────────────────────────

## Bind the controller to all game systems and load config.
## Call once after a level's GridState and PieceInventory are loaded.
##
## [param grid]       — runtime grid; must implement the RayPropagation interface.
## [param logic]      — sight lines orchestrator; recalculate_all_rays() called
##                      after every successful action.
## [param history]    — command history for undo/reset.
## [param inventory]  — piece inventory; validated and updated on every action.
## [param level_data] — immutable level definition; used to reload inventory on reset.
func setup(
		grid: GridState,
		logic: SightLinesLogic,
		history: CommandHistory,
		inventory: PieceInventory,
		level_data: LevelData) -> void:
	_grid       = grid
	_logic      = logic
	_history    = history
	_inventory  = inventory
	_level_data = level_data

	_load_config()
	_state = State.IDLE
	_selected_piece_type = -1

	# Lock input automatically when the puzzle is solved.
	if not _logic.puzzle_won.is_connected(_on_puzzle_won):
		_logic.puzzle_won.connect(_on_puzzle_won)

	# Restore inventory when the command history performs a reset.
	if not _history.history_reset.is_connected(_on_history_reset):
		_history.history_reset.connect(_on_history_reset)


# ── Public API ────────────────────────────────────────────────────────────────

## Select [param piece_type] for placement on the next valid SLOT click.
## Transitions IDLE → PIECE_SELECTED (or replaces the current selection).
## Does nothing if the controller is LOCKED or [param piece_type] is not
## available in inventory.
func select_piece_type(piece_type: int) -> void:
	if _state == State.LOCKED:
		return
	if _inventory == null or not _inventory.can_place(piece_type):
		return
	_selected_piece_type = piece_type
	_state = State.PIECE_SELECTED
	piece_type_selected.emit(piece_type)


## Deselect the current piece, returning to IDLE.
## Emits piece_deselected. Does nothing if already IDLE or LOCKED.
func deselect_piece() -> void:
	if _state == State.PIECE_SELECTED:
		_selected_piece_type = -1
		_state = State.IDLE
		piece_deselected.emit()


## Returns the currently selected PieceType int, or -1 when none is selected.
func get_selected_piece_type() -> int:
	return _selected_piece_type


## Returns the current interaction state.
func get_state() -> State:
	return _state


# ── Godot input hook ──────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _grid == null or _logic == null:
		return

	# ── Keyboard ──────────────────────────────────────────────────────────────
	if event is InputEventKey and event.pressed and not event.echo:
		if _action_pressed(event, "puzzle_undo", _KEY_UNDO):
			_handle_undo()
			get_viewport().set_input_as_handled()
			return
		if _action_pressed(event, "puzzle_reset", _KEY_RESET):
			_handle_reset()
			get_viewport().set_input_as_handled()
			return
		if _action_pressed(event, "puzzle_deselect", _KEY_DESELECT):
			deselect_piece()
			get_viewport().set_input_as_handled()
			return

	# All mouse handling requires the puzzle to be active.
	if _state == State.LOCKED:
		return

	# ── Mouse button ──────────────────────────────────────────────────────────
	if event is InputEventMouseButton and event.pressed:
		var cell: Vector2i = _screen_to_grid(event.position)
		if not _grid.is_in_bounds(cell):
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(cell)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(cell)
			get_viewport().set_input_as_handled()


# ── Private — action handlers ─────────────────────────────────────────────────

## Handle a left-click on [param cell].
## Behaviour depends on the current state and what occupies the cell.
func _handle_left_click(cell: Vector2i) -> void:
	match _state:
		State.PIECE_SELECTED:
			_try_place(cell)
		State.IDLE:
			_try_interact(cell)


## Handle a right-click on [param cell]: pick up any removable piece.
func _handle_right_click(cell: Vector2i) -> void:
	if _grid.get_piece_type(cell) == GridEnums.PieceType.NONE:
		return
	if _grid.is_piece_fixed(cell):
		return
	var cmd := RemovePieceCommand.new(_grid, cell.x, cell.y, _inventory)
	if _history.push(cmd):
		pass  # push() calls cmd.execute() internally
	_post_action()


## Attempt to place the selected piece type at [param cell].
## Transitions PIECE_SELECTED → IDLE on success; emits placement_rejected on fail.
func _try_place(cell: Vector2i) -> void:
	if not _grid.is_placeable(cell):
		# Cell occupied or not a SLOT — reject without deselecting.
		placement_rejected.emit()
		return
	var cmd := PlacePieceCommand.new(
			_grid, cell.x, cell.y,
			_selected_piece_type as GridEnums.PieceType,
			_default_direction,
			_inventory)
	_history.push(cmd)
	# Deselect and return to IDLE after placement (success or fail — push()
	# handles the false-execute case silently).
	_selected_piece_type = -1
	_state = State.IDLE
	piece_deselected.emit()
	_post_action()


## Attempt to interact with a placed piece at [param cell] while IDLE.
## Observer → rotate CW. Mirror → toggle orientation. Empty/fixed → no action.
func _try_interact(cell: Vector2i) -> void:
	var piece_type: int = _grid.get_piece_type(cell)
	if piece_type == GridEnums.PieceType.NONE:
		return  # Nothing to interact with.
	if _grid.is_piece_fixed(cell):
		return  # Fixed pieces cannot be rotated or toggled.

	match piece_type:
		GridEnums.PieceType.OBSERVER:
			var cmd := RotatePieceCommand.new(_grid, cell.x, cell.y)
			_history.push(cmd)
			_post_action()

		GridEnums.PieceType.MIRROR_FWDSLASH, GridEnums.PieceType.MIRROR_BKSLASH:
			var cmd := ToggleMirrorCommand.new(_grid, cell.x, cell.y)
			_history.push(cmd)
			_post_action()


## Undo the most recent command. Emits undo_unavailable when history is empty.
func _handle_undo() -> void:
	if _state == State.LOCKED:
		return
	if not _history.undo():
		undo_unavailable.emit()
		return
	_post_action()


## Reset the level: restore grid to initial snapshot and reload inventory.
## Clears the undo stack. Returns to IDLE.
func _handle_reset() -> void:
	if _state == State.LOCKED:
		return
	_history.reset()
	# history_reset signal triggers _on_history_reset → inventory reload.
	_selected_piece_type = -1
	_state = State.IDLE
	piece_deselected.emit()
	_post_action()


## Called after every action that may change grid state.
## Triggers ray recalculation and emits action_performed for UI/audio.
func _post_action() -> void:
	if _logic != null:
		_logic.recalculate_all_rays()
	action_performed.emit()


# ── Private — coordinate conversion ──────────────────────────────────────────

## Convert a screen-space [param screen_pos] to a grid (row, col) Vector2i.
## pos.x = row (vertical), pos.y = col (horizontal) — matches GridEnums convention.
func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var local: Vector2 = screen_pos - _grid_origin
	var col: int = int(local.x / _cell_size)
	var row: int = int(local.y / _cell_size)
	return Vector2i(row, col)


# ── Private — config loading ──────────────────────────────────────────────────

## Load visual configuration from the JSON config file.
## Silently uses defaults if the file is missing or malformed.
func _load_config() -> void:
	var path: String = "res://config/input_controller.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return  # File missing — use defaults.

	var raw: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_warning("InputController: config at '%s' is not a valid JSON object; using defaults." % path)
		return

	var cfg: Dictionary = parsed as Dictionary
	_cell_size    = float(cfg.get("cell_size",    _cell_size))
	_grid_origin  = Vector2(
		float(cfg.get("grid_origin_x", _grid_origin.x)),
		float(cfg.get("grid_origin_y", _grid_origin.y)))
	_default_direction = int(cfg.get("default_piece_direction", int(_default_direction))) as GridEnums.Direction


# ── Private — signal handlers ─────────────────────────────────────────────────

func _on_puzzle_won() -> void:
	_state = State.LOCKED
	_selected_piece_type = -1
	input_locked.emit()


## After CommandHistory.reset(), reload inventory from the original level data
## so piece counts match the fresh grid state.
func _on_history_reset() -> void:
	if _inventory != null and _level_data != null:
		_inventory.load_from_level_data(_level_data)


# ── Private — input helper ────────────────────────────────────────────────────

## Returns true if [param event] matches the named InputMap action (when
## registered) or the fallback [param key_code] (when the action is not found).
func _action_pressed(event: InputEventKey, action: StringName, key_code: int) -> bool:
	if InputMap.has_action(action):
		return event.is_action(action)
	return event.keycode == key_code
