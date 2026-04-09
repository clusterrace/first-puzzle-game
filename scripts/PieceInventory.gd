# PieceInventory.gd — Per-level piece inventory for Sight Lines (KAMA-17).
#
# Tracks how many of each PieceType the player has available to place on the
# grid for the current level.  All initial counts come from LevelData
# (config-driven); nothing is hardcoded here.
#
# Lifecycle:
#   var inv := PieceInventory.new()
#   inv.load_from_level_data(data)          # once per level load
#   inv.inventory_changed.connect(_on_inv)  # optional UI hook
#
#   # Before placing:
#   if inv.can_place(GridEnums.PieceType.OBSERVER):
#       inv.consume(GridEnums.PieceType.OBSERVER)
#
#   # After removing:
#   inv.return_piece(GridEnums.PieceType.OBSERVER)

class_name PieceInventory


# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted after any count change (consume or return).
## piece_type : GridEnums.PieceType int value that changed.
## new_count  : updated available count (>= 0) for that type.
signal inventory_changed(piece_type: int, new_count: int)


# ── Internal state ────────────────────────────────────────────────────────────

## Available counts by PieceType int value.
## Keys: int (GridEnums.PieceType). Values: int >= 0.
## Populated exclusively by load_from_level_data().
var _counts: Dictionary = {}


# ── Loading ───────────────────────────────────────────────────────────────────

## Reset and populate inventory from [param data].
## Call once when a level is loaded; clears any previous state.
##
## Reads LevelData.player_inventory (Array[int] of PieceType values).
## Multiple entries of the same type accumulate (e.g., [1, 1] → 2 observers).
func load_from_level_data(data: LevelData) -> void:
	_counts = {}
	for pt_int: Variant in data.player_inventory:
		var pt: int = int(pt_int)
		_counts[pt] = _counts.get(pt, 0) + 1


# ── Query API ─────────────────────────────────────────────────────────────────

## Returns how many pieces of [param piece_type] are currently available.
## Returns 0 for types not present in the level inventory.
func get_count(piece_type: int) -> int:
	return _counts.get(piece_type, 0)


## Returns true if at least one [param piece_type] piece is available to place.
func can_place(piece_type: int) -> bool:
	return get_count(piece_type) > 0


## Returns a typed array of PieceType int values that have count > 0.
## Useful for displaying the hand panel in the HUD.
func get_available_types() -> Array[int]:
	var result: Array[int] = []
	for pt: Variant in _counts:
		if _counts[pt] > 0:
			result.append(pt as int)
	return result


# ── Mutation API ──────────────────────────────────────────────────────────────

## Consume one [param piece_type] piece from inventory (piece placed on grid).
## Returns true on success.
## Returns false with no state change if none of that type are available.
func consume(piece_type: int) -> bool:
	var count: int = get_count(piece_type)
	if count <= 0:
		return false
	_counts[piece_type] = count - 1
	inventory_changed.emit(piece_type, count - 1)
	return true


## Return one [param piece_type] piece to inventory (piece removed from grid).
## Used when the player removes a placed piece or undo is applied.
func return_piece(piece_type: int) -> void:
	_counts[piece_type] = _counts.get(piece_type, 0) + 1
	inventory_changed.emit(piece_type, _counts[piece_type])
