class_name PlacePieceCommand
extends PuzzleCommand
## Command: place a piece on an empty SLOT cell.
##
## execute() — calls GridState.place_piece(). Returns false if the cell is
##             not an empty SLOT (placement rejected, nothing pushed to history).
## undo()    — calls GridState.remove_piece() to return the cell to empty.


var _grid: GridState
var _row: int
var _col: int
var _piece_type: GridEnums.PieceType
var _direction: GridEnums.Direction


func _init(
		grid: GridState,
		row: int,
		col: int,
		piece_type: GridEnums.PieceType,
		direction: GridEnums.Direction) -> void:
	_grid       = grid
	_row        = row
	_col        = col
	_piece_type = piece_type
	_direction  = direction


func execute() -> bool:
	return _grid.place_piece(_row, _col, _piece_type, _direction)


func undo() -> void:
	_grid.remove_piece(_row, _col)
