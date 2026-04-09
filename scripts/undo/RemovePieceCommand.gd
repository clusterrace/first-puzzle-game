class_name RemovePieceCommand
extends PuzzleCommand
## Command: remove a player-placed piece from a SLOT cell.
##
## execute() — reads the piece state from the grid, calls GridState.remove_piece(),
##             and returns piece to inventory (when inventory is bound).
##             Returns false if there is no removable piece at the cell.
## undo()    — calls GridState.place_piece() with the saved piece state and
##             consumes one piece from inventory (when bound), restoring the
##             cell exactly as it was before execute().
##
## The piece type and direction are captured at construction time so undo()
## always has valid data regardless of what happens between execute() and undo().
##
## The optional [param inventory] parameter enables inventory integration for
## S3 input handling (KAMA-18). When null (default), only grid state is managed.


var _grid: GridState
var _inventory: PieceInventory  # null when not used
var _row: int
var _col: int
var _saved_piece_type: GridEnums.PieceType
var _saved_direction: GridEnums.Direction


## [param grid] must contain a non-fixed piece at ([param row], [param col])
## before this command is executed. The piece state is captured here so undo()
## can restore it unconditionally.
func _init(
		grid: GridState,
		row: int,
		col: int,
		inventory: PieceInventory = null) -> void:
	_grid             = grid
	_inventory        = inventory
	_row              = row
	_col              = col
	_saved_piece_type = grid.get_piece_type(Vector2i(row, col))
	_saved_direction  = grid.get_piece_direction(Vector2i(row, col))


func execute() -> bool:
	if not _grid.remove_piece(Vector2i(_row, _col)):
		return false
	if _inventory != null:
		_inventory.return_piece(_saved_piece_type)
	return true


func undo() -> void:
	_grid.place_piece(Vector2i(_row, _col), _saved_piece_type, _saved_direction)
	if _inventory != null:
		_inventory.consume(_saved_piece_type)
