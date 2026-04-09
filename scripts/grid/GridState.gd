class_name GridState
## Runtime mutable model of the Sight Lines puzzle grid.
##
## Responsibilities:
##   - Canonical truth of all tile types and piece placements.
##   - Enforces placement rules (only empty SLOT tiles accept pieces).
##   - Exposes the full query and mutation API consumed by S2 (ray tracing),
##     S3 (player interaction), and S4 (AV feedback).
##   - Snapshots for the undo/reset system (S1 sub-task KAMA-15).
##
## Coordinate convention throughout:
##   Function parameters use (row: int, col: int).
##   Returned Vector2i positions use Vector2i(row, col) — .x = row, .y = col.
##   This matches the prototype convention and the DIRECTION_DELTA table in
##   GridEnums. Do NOT confuse with Godot screen-space (x = horizontal).


## Emitted after any piece placement, removal, rotation, or snapshot restore.
## The ray-tracing system (S2) connects to this signal to recompute rays.
## set_target_lit() does NOT emit this signal to avoid re-entrant loops.
signal state_changed()


# ---------------------------------------------------------------------------
# Inner type
# ---------------------------------------------------------------------------

class Cell:
	## Tile type — permanent, from authored level data.
	var tile_type: GridEnums.TileType = GridEnums.TileType.EMPTY
	## Piece occupying this tile. NONE if empty.
	var piece_type: GridEnums.PieceType = GridEnums.PieceType.NONE
	## Facing direction of the piece. Only meaningful when piece_type != NONE.
	var piece_direction: GridEnums.Direction = GridEnums.Direction.NORTH
	## True when this piece was pre-placed by the level author (cannot be removed
	## or rotated by the player).
	var piece_is_fixed: bool = false
	## Lit state, updated by the ray-tracing system after each state change.
	## Only meaningful for TARGET tiles.
	var is_lit: bool = false

	func _init(p_tile: GridEnums.TileType) -> void:
		tile_type = p_tile


# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

## Grid dimensions, set by load_from_level_data().
var rows: int = 0
var cols: int = 0

## Flat row-major array of Cell objects. Index = row * cols + col.
## Access via _get_cell(); do not index directly from outside this class.
var _cells: Array = []


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

## Populates the grid from [param data].
## Clears any previous state. Emits state_changed.
func load_from_level_data(data: LevelData) -> void:
	rows = data.rows
	cols = data.cols
	_cells.clear()
	_cells.resize(rows * cols)

	# Build base tile cells.
	for r: int in range(rows):
		for c: int in range(cols):
			var tile_val: int = data.tile_grid[r * cols + c]
			_cells[r * cols + c] = Cell.new(tile_val as GridEnums.TileType)

	# Place fixed pieces on top of their slots.
	for fp: Dictionary in data.fixed_pieces:
		var r: int = fp["row"]
		var c: int = fp["col"]
		if not is_in_bounds(r, c):
			push_error("GridState: fixed piece out of bounds at (%d, %d)" % [r, c])
			continue
		var cell: Cell = _get_cell(r, c)
		cell.piece_type      = fp["piece_type"] as GridEnums.PieceType
		cell.piece_direction = fp["direction"]  as GridEnums.Direction
		cell.piece_is_fixed  = true

	state_changed.emit()


# ---------------------------------------------------------------------------
# Query API
# ---------------------------------------------------------------------------

## Returns true when (row, col) is within the grid boundaries.
func is_in_bounds(row: int, col: int) -> bool:
	return row >= 0 and row < rows and col >= 0 and col < cols


## Returns the base TileType of the cell. Asserts bounds.
func get_tile_type(row: int, col: int) -> GridEnums.TileType:
	return _get_cell(row, col).tile_type


## Returns the PieceType occupying the cell (NONE if empty).
func get_piece_type(row: int, col: int) -> GridEnums.PieceType:
	return _get_cell(row, col).piece_type


## Returns the facing direction of the piece at (row, col).
## Only meaningful when get_piece_type() != NONE.
func get_piece_direction(row: int, col: int) -> GridEnums.Direction:
	return _get_cell(row, col).piece_direction


## Returns true when the piece at (row, col) is a fixed (author-placed) piece.
func is_piece_fixed(row: int, col: int) -> bool:
	return _get_cell(row, col).piece_is_fixed


## Returns true when the cell is lit.
## Only meaningful for TARGET tiles; always false for other tile types.
func is_target_lit(row: int, col: int) -> bool:
	return _get_cell(row, col).is_lit


## Returns true when the player can place a piece here:
##   tile_type == SLOT and no piece is currently present.
func is_placeable(row: int, col: int) -> bool:
	if not is_in_bounds(row, col):
		return false
	var cell: Cell = _get_cell(row, col)
	return (cell.tile_type  == GridEnums.TileType.SLOT
		and cell.piece_type == GridEnums.PieceType.NONE)


## Returns positions (Vector2i(row, col)) of every TARGET tile in the grid.
func get_all_targets() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for r: int in range(rows):
		for c: int in range(cols):
			if _get_cell(r, c).tile_type == GridEnums.TileType.TARGET:
				result.append(Vector2i(r, c))
	return result


## Returns positions (Vector2i(row, col)) of every tile that carries an
## OBSERVER piece, whether fixed or player-placed.
func get_all_observers() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for r: int in range(rows):
		for c: int in range(cols):
			if _get_cell(r, c).piece_type == GridEnums.PieceType.OBSERVER:
				result.append(Vector2i(r, c))
	return result


# ---------------------------------------------------------------------------
# Mutation API
# ---------------------------------------------------------------------------

## Places [param piece_type] facing [param direction] at (row, col).
## Only succeeds on empty SLOT cells (is_placeable() == true).
## Returns true on success, false on failure (no signal emitted on failure).
func place_piece(
		row: int,
		col: int,
		piece_type: GridEnums.PieceType,
		direction: GridEnums.Direction) -> bool:
	if not is_placeable(row, col):
		return false
	var cell: Cell = _get_cell(row, col)
	cell.piece_type      = piece_type
	cell.piece_direction = direction
	cell.piece_is_fixed  = false
	state_changed.emit()
	return true


## Removes the player-placed piece at (row, col).
## Returns false if there is no piece or the piece is fixed.
## Fixed pieces are immovable and cannot be removed.
func remove_piece(row: int, col: int) -> bool:
	if not is_in_bounds(row, col):
		return false
	var cell: Cell = _get_cell(row, col)
	if cell.piece_type == GridEnums.PieceType.NONE or cell.piece_is_fixed:
		return false
	cell.piece_type = GridEnums.PieceType.NONE
	state_changed.emit()
	return true


## Rotates the player-placed piece at (row, col) 90 degrees clockwise.
## Returns false if there is no piece or the piece is fixed.
func rotate_piece_cw(row: int, col: int) -> bool:
	if not is_in_bounds(row, col):
		return false
	var cell: Cell = _get_cell(row, col)
	if cell.piece_type == GridEnums.PieceType.NONE or cell.piece_is_fixed:
		return false
	cell.piece_direction = GridEnums.rotate_cw(cell.piece_direction)
	state_changed.emit()
	return true


## Updates the lit state of a TARGET tile.
## Called by the ray-tracing system (S2) after recomputing rays.
## Does NOT emit state_changed (to avoid re-entrant signal loops).
func set_target_lit(row: int, col: int, lit: bool) -> void:
	if not is_in_bounds(row, col):
		return
	var cell: Cell = _get_cell(row, col)
	if cell.tile_type != GridEnums.TileType.TARGET:
		return
	cell.is_lit = lit


## Clears the lit state on all TARGET tiles. Call before recomputing rays.
func clear_all_lit() -> void:
	for r: int in range(rows):
		for c: int in range(cols):
			var cell: Cell = _get_cell(r, c)
			if cell.tile_type == GridEnums.TileType.TARGET:
				cell.is_lit = false


## Removes all player-placed (non-fixed) pieces from the grid.
## Emits state_changed once.
func reset_all_player_pieces() -> void:
	_clear_player_pieces()
	state_changed.emit()


# ---------------------------------------------------------------------------
# Snapshot API (for undo/reset — KAMA-15)
# ---------------------------------------------------------------------------

## Returns a snapshot of all current player-placed (non-fixed) pieces.
## Format: Array[Dictionary], each entry has keys:
##   row (int), col (int), piece_type (int), piece_direction (int)
## Pass to restore_piece_snapshot() to replay a prior state.
func get_piece_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for r: int in range(rows):
		for c: int in range(cols):
			var cell: Cell = _get_cell(r, c)
			if cell.piece_type != GridEnums.PieceType.NONE and not cell.piece_is_fixed:
				snapshot.append({
					"row":            r,
					"col":            c,
					"piece_type":     cell.piece_type,
					"piece_direction": cell.piece_direction,
				})
	return snapshot


## Replaces all player-placed pieces with the contents of [param snapshot].
## Fixed pieces are not affected. Emits state_changed once.
func restore_piece_snapshot(snapshot: Array[Dictionary]) -> void:
	_clear_player_pieces()
	for entry: Dictionary in snapshot:
		var cell: Cell = _get_cell(entry["row"], entry["col"])
		cell.piece_type      = entry["piece_type"]      as GridEnums.PieceType
		cell.piece_direction = entry["piece_direction"] as GridEnums.Direction
		cell.piece_is_fixed  = false
	state_changed.emit()


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _get_cell(row: int, col: int) -> Cell:
	return _cells[row * cols + col] as Cell


func _clear_player_pieces() -> void:
	for i: int in range(_cells.size()):
		var cell: Cell = _cells[i] as Cell
		if cell.piece_type != GridEnums.PieceType.NONE and not cell.piece_is_fixed:
			cell.piece_type = GridEnums.PieceType.NONE
