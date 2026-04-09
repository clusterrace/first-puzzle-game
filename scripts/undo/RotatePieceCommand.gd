class_name RotatePieceCommand
extends PuzzleCommand
## Command: rotate a player-placed piece 90 degrees clockwise.
##
## execute() — calls GridState.rotate_piece_cw(). Returns false if the cell
##             has no movable piece (rejected, nothing pushed to history).
## undo()    — applies three additional CW rotations, which equals one CCW
##             rotation, restoring the original facing direction.
##
## Note: undo() emits three state_changed signals on GridState (one per
## rotate call). This is expected and each intermediate state is valid.


var _grid: GridState
var _row: int
var _col: int


func _init(grid: GridState, row: int, col: int) -> void:
	_grid = grid
	_row  = row
	_col  = col


func execute() -> bool:
	return _grid.rotate_piece_cw(Vector2i(_row, _col))


func undo() -> void:
	# Three CW rotations = one CCW rotation (full 360° minus one step).
	_grid.rotate_piece_cw(Vector2i(_row, _col))
	_grid.rotate_piece_cw(Vector2i(_row, _col))
	_grid.rotate_piece_cw(Vector2i(_row, _col))
