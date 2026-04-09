class_name RemovePieceCommand
extends PuzzleCommand
## Command: remove a player-placed piece from a SLOT cell.
##
## execute() — reads the piece state from the grid, then calls
##             GridState.remove_piece(). Returns false if there is no
##             removable piece at the cell (rejected, nothing pushed).
## undo()    — calls GridState.place_piece() with the saved piece state,
##             restoring the cell exactly as it was before execute().
##
## The piece type and direction are captured at construction time so that
## undo() always has valid data regardless of what happens between execute()
## and undo() being called.


var _grid: GridState
var _row: int
var _col: int
var _saved_piece_type: GridEnums.PieceType
var _saved_direction: GridEnums.Direction


## [param grid] must contain a non-fixed piece at ([param row], [param col])
## before this command is executed. The piece state is read here so undo()
## can restore it unconditionally.
func _init(grid: GridState, row: int, col: int) -> void:
	_grid             = grid
	_row              = row
	_col              = col
	_saved_piece_type = grid.get_piece_type(row, col)
	_saved_direction  = grid.get_piece_direction(row, col)


func execute() -> bool:
	return _grid.remove_piece(_row, _col)


func undo() -> void:
	_grid.place_piece(_row, _col, _saved_piece_type, _saved_direction)
