# SightLinesLogic.gd — Sight Lines game logic orchestrator.
#
# Bridges the grid data layer (GridData / GridState from KAMA-11) and the ray
# engine (RayPropagation). Emits fine-grained signals for every state change so
# the display and audio layers can react without any logic coupling.
#
# Also owns the piece inventory (KAMA-17): validates placements against both
# grid rules and available inventory before committing any state change.
#
# Zero visual/audio code. Zero input handling code.
# All player actions arrive via the public API (try_place_piece, try_remove_piece, etc.)
# All display/audio reactions subscribe to signals emitted by this node.
#
# Coordinate convention: Vector2i(row, col) — pos.x = row, pos.y = col.
# Matches GridEnums.DIRECTION_DELTA.
#
# Usage:
#   var logic := SightLinesLogic.new()
#   add_child(logic)
#   logic.bind_grid(grid_state)               # call once after level loads
#   logic.bind_inventory(piece_inventory)     # call once after level loads
#   logic.ray_paths_updated.connect(_on_ray_paths_updated)
#   logic.target_lit.connect(_on_target_lit)
#   logic.target_unlit.connect(_on_target_unlit)
#   logic.puzzle_won.connect(_on_puzzle_won)
#   # Player placement:
#   logic.try_place_piece(Vector2i(2, 3), GridEnums.PieceType.OBSERVER, GridEnums.Direction.EAST)
#   logic.try_remove_piece(Vector2i(2, 3))

class_name SightLinesLogic extends Node


# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted after every full recalculation with the current ray path map.
## path_map: Dictionary { Vector2i(row,col) → Array of Vector2i(row,col) }
## Keys are observer positions; values are ordered lists of tiles each ray visited.
signal ray_paths_updated(path_map: Dictionary)

## Emitted when the target at [param pos] transitions from unlit → lit.
signal target_lit(pos: Vector2i)

## Emitted when the target at [param pos] transitions from lit → unlit.
signal target_unlit(pos: Vector2i)

## Emitted once when all targets become simultaneously lit.
## The interaction layer (S3) should lock input upon receiving this signal.
signal puzzle_won()


# ── Internal state ────────────────────────────────────────────────────────────

## Bound grid state object. Must implement the RayPropagation grid interface.
## Set via bind_grid(). Null until bound.
var _grid: Object = null

## Bound piece inventory. Set via bind_inventory(). Null until bound.
## When null, inventory checks are skipped (grid-only validation).
var _inventory: PieceInventory = null

## True after puzzle_won has been emitted for the current level.
## Gates re-emission so puzzle_won fires at most once per bound grid.
var _puzzle_solved: bool = false

## Lit state snapshot from the previous recalculation.
## Diff against current state to emit per-target signals.
## Keys: Vector2i(row, col). Values: bool.
var _prev_lit: Dictionary = {}


# ── Public API — Setup ────────────────────────────────────────────────────────

## Bind this logic node to a runtime grid state object and run the initial
## recalculation. Call once when a level's grid state is ready.
##
## grid_obj must implement the RayPropagation grid interface:
##   get_tile_type, get_piece_type, get_piece_direction,
##   get_all_observers, get_all_targets,
##   set_target_lit, is_target_lit, is_in_bounds
func bind_grid(grid_obj: Object) -> void:
	_grid = grid_obj
	_puzzle_solved = false
	_rebuild_prev_lit_snapshot()
	recalculate_all_rays()


## Unbind the current grid (e.g., when transitioning between levels).
## Clears all internal state without emitting signals.
func unbind_grid() -> void:
	_grid = null
	_puzzle_solved = false
	_prev_lit = {}


## Bind a PieceInventory to this logic node.
## Must be called after bind_grid() when inventory management is required.
## Pass null to disable inventory checks (useful for testing or editor tools).
func bind_inventory(inv: PieceInventory) -> void:
	_inventory = inv


## Returns the currently bound PieceInventory, or null if none is bound.
func get_inventory() -> PieceInventory:
	return _inventory


# ── Public API — Player actions ───────────────────────────────────────────────

## Attempt to place [param piece_type] facing [param direction] at [param pos].
##
## Validates atomically — both checks must pass before any state changes:
##   1. Grid: pos must be an empty SLOT tile (spec E6).
##   2. Inventory: at least one piece of that type must be available.
##
## On success:
##   - Consumes one piece from inventory.
##   - Places piece on grid.
##   - Recalculates all rays and emits signals.
##   - Returns true.
##
## On failure (either check fails):
##   - No state change.
##   - Returns false.
##   - Caller is responsible for any rejection feedback (audio/UI).
func try_place_piece(
		pos: Vector2i,
		piece_type: int,
		direction: int) -> bool:

	if _grid == null:
		push_error("SightLinesLogic.try_place_piece: no grid bound.")
		return false

	# Grid validation: must be an empty SLOT (rejects walls, targets, occupied, fixed).
	if not _grid.is_placeable(pos):
		return false

	# Inventory validation: must have at least one piece of this type.
	if _inventory != null and not _inventory.can_place(piece_type):
		return false

	# Both checks passed — commit atomically.
	if _inventory != null:
		_inventory.consume(piece_type)
	_grid.place_piece(pos, piece_type as GridEnums.PieceType, direction as GridEnums.Direction)
	recalculate_all_rays()
	return true


## Attempt to remove the player-placed piece at [param pos].
##
## Conditions for success:
##   - A non-fixed piece must be present at pos.
##
## On success:
##   - Returns the piece to inventory.
##   - Removes piece from grid.
##   - Recalculates all rays and emits signals.
##   - Returns true.
##
## On failure (no removable piece):
##   - No state change.
##   - Returns false.
func try_remove_piece(pos: Vector2i) -> bool:
	if _grid == null:
		push_error("SightLinesLogic.try_remove_piece: no grid bound.")
		return false

	# Validate: must have a non-fixed piece.
	if not _grid.is_in_bounds(pos):
		return false
	var piece_type: int = _grid.get_piece_type(pos)
	if piece_type == GridEnums.PieceType.NONE:
		return false
	if _grid.is_piece_fixed(pos):
		return false

	# Commit: remove from grid, then return to inventory.
	_grid.remove_piece(pos)
	if _inventory != null:
		_inventory.return_piece(piece_type)
	recalculate_all_rays()
	return true


# ── Public API — Recalculation ────────────────────────────────────────────────

## Trigger a full ray recalculation and emit all relevant signals.
##
## Call this after every player action that changes grid state:
##   - piece placed or removed (prefer try_place_piece / try_remove_piece)
##   - observer rotated
##   - mirror orientation toggled
##   - undo or reset applied
##
## Signal emission order:
##   1. target_unlit — for each target that transitioned lit → unlit
##   2. target_lit   — for each target that transitioned unlit → lit
##   3. ray_paths_updated — always, with current path map
##   4. puzzle_won   — at most once per bound grid, when win first reached
func recalculate_all_rays() -> void:
	if _grid == null:
		push_error("SightLinesLogic.recalculate_all_rays: no grid bound. Call bind_grid() first.")
		return

	var result: Dictionary    = RayPropagation.recalculate(_grid)
	var ray_paths: Dictionary = result["ray_paths"]
	var won: bool             = result["win"]

	# Diff previous lit snapshot to emit per-target signals.
	for target_pos: Vector2i in _grid.get_all_targets():
		var was_lit: bool = _prev_lit.get(target_pos, false)
		var is_lit: bool  = _grid.is_target_lit(target_pos)

		if was_lit and not is_lit:
			target_unlit.emit(target_pos)
		elif not was_lit and is_lit:
			target_lit.emit(target_pos)

		_prev_lit[target_pos] = is_lit

	# Always broadcast the updated path map to the display layer.
	ray_paths_updated.emit(ray_paths)

	# Fire puzzle_won at most once per level.
	if won and not _puzzle_solved:
		_puzzle_solved = true
		puzzle_won.emit()


## Returns true if the puzzle has been solved (puzzle_won was emitted).
## Useful as an input guard in the interaction layer (S3).
func is_solved() -> bool:
	return _puzzle_solved


# ── Private helpers ───────────────────────────────────────────────────────────

## Rebuild the lit snapshot from current grid state.
## Ensures the first recalculate diff is accurate even if targets were pre-lit.
func _rebuild_prev_lit_snapshot() -> void:
	_prev_lit = {}
	if _grid == null:
		return
	for target_pos: Vector2i in _grid.get_all_targets():
		_prev_lit[target_pos] = _grid.is_target_lit(target_pos)
