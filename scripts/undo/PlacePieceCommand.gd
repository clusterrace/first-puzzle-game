class_name PlacePieceCommand
extends PuzzleCommand
## Command: place a piece on an empty SLOT cell.
##
## execute() — validates inventory (if bound), then calls GridState.place_piece().
##             Returns false and makes no state change if the cell is not an
##             empty SLOT, or if inventory is bound but has no piece of that type.
## undo()    — calls GridState.remove_piece() and returns piece to inventory
##             (when inventory is bound).
##
## The optional [param inventory] parameter enables inventory integration for
## S3 input handling (KAMA-18). When null (default), only grid state is managed
## and the existing KAMA-15 unit tests continue to pass unchanged.


var _grid: GridState
var _inventory: PieceInventory  # null when not used
var _row: int
var _col: int
var _piece_type: GridEnums.PieceType
var _direction: GridEnums.Direction


func _init(
		grid: GridState,
		row: int,
		col: int,
		piece_type: GridEnums.PieceType,
		direction: GridEnums.Direction,
		inventory: PieceInventory = null) -> void:
	_grid       = grid
	_inventory  = inventory
	_row        = row
	_col        = col
	_piece_type = piece_type
	_direction  = direction


func execute() -> bool:
	# Inventory check first — no state change if insufficient pieces.
	if _inventory != null and not _inventory.can_place(_piece_type):
		return false
	# Grid check — rejects occupied cells, walls, targets, out-of-bounds.
	if not _grid.place_piece(Vector2i(_row, _col), _piece_type, _direction):
		return false
	# Commit inventory after grid succeeds.
	if _inventory != null:
		_inventory.consume(_piece_type)
	return true


func undo() -> void:
	_grid.remove_piece(Vector2i(_row, _col))
	if _inventory != null:
		_inventory.return_piece(_piece_type)
