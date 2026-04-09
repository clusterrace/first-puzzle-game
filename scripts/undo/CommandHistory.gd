class_name CommandHistory
## Manages the undo stack and reset point for the puzzle command system.
##
## Usage per level:
##   1. Call initialize() with the GridState and the initial piece snapshot
##      captured immediately after the level is loaded.
##   2. Wrap each player action in the appropriate PuzzleCommand subclass
##      and pass it to push(). The command is executed and, if successful,
##      recorded.
##   3. Call undo() to reverse the most recent action one step at a time.
##   4. Call reset() to restore the board to the authored initial state and
##      clear all history.
##
## Signals:
##   undo_available_changed — fires whenever can_undo() changes value; use
##                            this to enable/disable the undo UI button.
##   history_reset          — fires after reset() completes.


## Fired when the undo stack transitions between empty and non-empty.
signal undo_available_changed(available: bool)

## Fired after reset() restores the initial snapshot.
signal history_reset()


var _grid: GridState
var _stack: Array[PuzzleCommand] = []
var _initial_snapshot: Array[Dictionary] = []

## Maximum commands kept in history. 0 = unlimited (default).
## When the cap is exceeded the oldest entry is silently dropped.
var max_history_size: int = 0


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Prepares the history for a new level.
## Call once after GridState.load_from_level_data() and before any player
## actions are accepted.
##
## [param grid]             — runtime grid the commands will mutate.
## [param initial_snapshot] — GridState.get_piece_snapshot() taken right
##                            after level load; defines the reset target.
## [param p_max_size]       — history depth cap; 0 = unlimited.
func initialize(
		grid: GridState,
		initial_snapshot: Array[Dictionary],
		p_max_size: int = 0) -> void:
	_grid             = grid
	_initial_snapshot = initial_snapshot
	max_history_size  = p_max_size
	clear()


# ---------------------------------------------------------------------------
# Command dispatch
# ---------------------------------------------------------------------------

## Executes [param cmd] and, if it succeeds, pushes it onto the undo stack.
## If cmd.execute() returns false the command is discarded silently.
## When max_history_size > 0 and the stack is full, the oldest entry is
## evicted to make room.
func push(cmd: PuzzleCommand) -> void:
	var was_available: bool = can_undo()
	if not cmd.execute():
		return
	_stack.push_back(cmd)
	if max_history_size > 0 and _stack.size() > max_history_size:
		_stack.pop_front()
	if can_undo() != was_available:
		undo_available_changed.emit(can_undo())


# ---------------------------------------------------------------------------
# Undo
# ---------------------------------------------------------------------------

## Reverses the most recent command.
## Returns true if an undo was performed, false when the stack is empty.
func undo() -> bool:
	if _stack.is_empty():
		return false
	var was_available: bool = can_undo()
	var cmd: PuzzleCommand = _stack.pop_back()
	cmd.undo()
	if can_undo() != was_available:
		undo_available_changed.emit(can_undo())
	return true


# ---------------------------------------------------------------------------
# Reset
# ---------------------------------------------------------------------------

## Restores the grid to the initial snapshot captured in initialize() and
## clears the entire undo stack. Emits history_reset when done.
func reset() -> void:
	_grid.restore_piece_snapshot(_initial_snapshot)
	clear()
	history_reset.emit()


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## Returns true when there is at least one command that can be undone.
func can_undo() -> bool:
	return not _stack.is_empty()


## Returns the number of commands currently on the undo stack.
func history_size() -> int:
	return _stack.size()


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Discards all history without touching the grid.
## Emits undo_available_changed if the stack was non-empty.
func clear() -> void:
	var was_available: bool = can_undo()
	_stack.clear()
	if can_undo() != was_available:
		undo_available_changed.emit(can_undo())
