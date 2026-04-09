class_name ToggleMirrorCommand
extends PuzzleCommand
## Command: toggle a mirror piece between / (MIRROR_FWDSLASH) and
## \ (MIRROR_BKSLASH) orientation.
##
## execute() — calls GridState.toggle_mirror_orientation(). Returns false if
##             the cell contains no mirror or the piece is fixed.
## undo()    — calls toggle_mirror_orientation() again. The toggle is its own
##             inverse, so one additional call restores the original orientation.
##
## No inventory change: mirror orientation toggle does not consume or return
## pieces; it only modifies an already-placed mirror's type.


var _grid: GridState
var _row: int
var _col: int


func _init(grid: GridState, row: int, col: int) -> void:
	_grid = grid
	_row  = row
	_col  = col


func execute() -> bool:
	return _grid.toggle_mirror_orientation(Vector2i(_row, _col))


func undo() -> void:
	# Toggle is self-inverse: one additional call restores original orientation.
	_grid.toggle_mirror_orientation(Vector2i(_row, _col))
