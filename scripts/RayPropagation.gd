# RayPropagation.gd — Sight Lines ray propagation and mirror reflection algorithms.
#
# Pure algorithm module: no Node inheritance, no signals, no visual/audio code.
# Implements spec Sections 4.1–4.4 from KAMA-8#document-s2-core-mechanic.
# Integrates with the GridEnums / GridData API produced by KAMA-11.
#
# ── Coordinate convention ──────────────────────────────────────────────────────
# Positions are Vector2i(row, col) throughout, matching GridEnums.DIRECTION_DELTA.
#   pos.x = row  (y-axis in screen space)
#   pos.y = col  (x-axis in screen space)
# Do NOT mix with Godot screen-space Vector2 where x = horizontal.
#
# ── Grid interface (duck-typed) ────────────────────────────────────────────────
# All static methods accept a `grid` parameter that must implement:
#
#   get_tile_type(pos: Vector2i) -> int
#       Returns a GridEnums.TileType value for the base cell type at pos.
#       Valid values: EMPTY, WALL, SLOT, TARGET.
#
#   get_piece_type(pos: Vector2i) -> int
#       Returns a GridEnums.PieceType value for any piece currently on pos.
#       NONE when no piece occupies the cell.
#
#   get_piece_direction(pos: Vector2i) -> int
#       Returns a GridEnums.Direction value for the piece at pos.
#       Used to retrieve an observer's facing direction.
#
#   get_all_observers() -> Array
#       Returns Array of Vector2i(row, col) positions of every observer on grid.
#       Includes both fixed and player-placed observers.
#
#   get_all_targets() -> Array
#       Returns Array of Vector2i(row, col) positions of every TARGET tile.
#
#   set_target_lit(pos: Vector2i, lit: bool) -> void
#       Marks the target at pos as lit or unlit. Must be idempotent.
#
#   is_target_lit(pos: Vector2i) -> bool
#       Returns the current lit state of the target at pos.
#
#   is_in_bounds(pos: Vector2i) -> bool
#       Returns true when pos is within the valid grid rectangle.

class_name RayPropagation


# ── Section 4.2 — Mirror Reflection ──────────────────────────────────────────

## Reflect a ray direction off a mirror piece.
##
## Delegates to GridEnums.reflect_direction, which owns the canonical lookup:
##   MIRROR_FWDSLASH  (/)  N→E, E→N, S→W, W→S
##   MIRROR_BKSLASH   (\)  N→W, W→N, S→E, E→S
##
## Returns [param in_dir] unchanged when:
##   - [param piece_type] is not a mirror variant (non-reflective pass-through)
##   - [param in_dir] is not in the mirror's reflection table
##
## Edge case E5: no infinite loops possible with cardinal-only movement on a
## finite grid. Any sequence of reflections must eventually drive the ray out of
## bounds or into a wall.
static func reflect(in_dir: int, piece_type: int) -> int:
	return GridEnums.reflect_direction(
			in_dir as GridEnums.Direction,
			piece_type as GridEnums.PieceType)


# ── Section 4.1 — Ray Propagation ─────────────────────────────────────────────

## Propagate a single sight ray from [param observer_pos] in [param direction].
##
## observer_pos : Vector2i(row, col) of the emitting observer.
## direction    : GridEnums.Direction int (NORTH=0, EAST=1, SOUTH=2, WEST=3).
##
## The ray starts one tile ahead of the observer (observer's own tile is skipped).
## Iterates tile-by-tile using GridEnums.DIRECTION_DELTA for movement.
## Calls grid.set_target_lit(pos, true) for every TARGET tile the ray traverses.
##
## Returns: ordered Array of Vector2i(row, col) tiles the ray visited,
##          not including the observer tile, including the terminal tile.
##
## Edge cases handled per spec:
##   E1: multiple rays hit the same target — set_target_lit is idempotent; all light it.
##   E2: observer adjacent to wall → path length = 1; terminates immediately.
##   E5: finite grid + cardinal movement → loop always terminates.
##   E9: ray passes through OBSERVER piece tiles unchanged.
static func propagate_ray(
		grid: Object,
		observer_pos: Vector2i,
		direction: int) -> Array:

	var path: Array = []
	var dir: int = direction
	var current: Vector2i = observer_pos + GridEnums.DIRECTION_DELTA[dir]

	while grid.is_in_bounds(current):
		path.append(current)

		var tile_type: int  = grid.get_tile_type(current)
		var piece_type: int = grid.get_piece_type(current)

		# Evaluation order matters — check WALL first (terminates), then mirror
		# (redirects), then TARGET (lights + continues), then fall through.
		if tile_type == GridEnums.TileType.WALL:
			break  # Ray terminates at wall; wall tile included in path (E2).

		elif piece_type == GridEnums.PieceType.MIRROR_FWDSLASH \
				or piece_type == GridEnums.PieceType.MIRROR_BKSLASH:
			dir = reflect(dir, piece_type)
			# Do NOT break — ray continues in the reflected direction.

		elif tile_type == GridEnums.TileType.TARGET:
			grid.set_target_lit(current, true)
			# Do NOT break — ray passes through target tiles (E1).

		# EMPTY, SLOT with NONE piece, SLOT with OBSERVER piece: pass through (E9).

		current = current + GridEnums.DIRECTION_DELTA[dir]

	return path


# ── Section 4.3 — Win Condition Check ────────────────────────────────────────

## Returns true when every target on the grid is simultaneously lit.
## Returns false immediately when any target is unlit, or when no targets exist.
## A grid with no targets cannot be won (returns false per spec rule 3.6).
static func check_win(grid: Object) -> bool:
	var targets: Array = grid.get_all_targets()
	if targets.is_empty():
		return false
	for pos: Vector2i in targets:
		if not grid.is_target_lit(pos):
			return false
	return true


# ── Section 4.4 — Full State Recalculation ───────────────────────────────────

## Clear all target lit states, propagate every observer's ray, check win.
## Must be called after every player action that changes grid state.
##
## Returns a Dictionary with:
##   "ray_paths" : Dictionary { Vector2i(row,col) → Array of Vector2i(row,col) }
##                 Maps each observer position to the ordered list of tiles its
##                 ray visited. Empty dict when no observers are on the grid.
##   "win"       : bool — true if all targets are simultaneously lit.
##
## Complexity: O(N*M) per call. Runs <1ms on 20×20 grid per spec Section 4.4.
## No spatial caching is needed for puzzle sizes expected in this game.
static func recalculate(grid: Object) -> Dictionary:
	# Step 1: Clear all lit states.
	for target_pos: Vector2i in grid.get_all_targets():
		grid.set_target_lit(target_pos, false)

	# Step 2: Propagate every observer's ray.
	var ray_paths: Dictionary = {}
	for obs_pos: Vector2i in grid.get_all_observers():
		var facing: int = grid.get_piece_direction(obs_pos)
		var path: Array = propagate_ray(grid, obs_pos, facing)
		ray_paths[obs_pos] = path

	# Step 3: Evaluate win condition.
	var won: bool = check_win(grid)

	return {"ray_paths": ray_paths, "win": won}
