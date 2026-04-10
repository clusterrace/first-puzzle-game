class_name GridEnums
## Shared enums, constants, and pure helpers for the Sight Lines grid system.
## Import by referencing GridEnums.TileType, GridEnums.PieceType, etc.


## Base classification of a grid cell — fixed at level-authoring time and never
## changed at runtime. Determines what can occupy the cell and how rays interact.
enum TileType {
	EMPTY         = 0,  ## Passable open cell; not placeable, does not block rays.
	WALL          = 1,  ## Impassable; terminates sight rays. Cannot be placed on.
	SLOT          = 2,  ## Player-placeable slot; may hold a fixed or player piece.
	TARGET        = 3,  ## Must be hit by a sight ray to satisfy the win condition.
	                    ## Rays pass through; cannot be placed on.
	TARGET_AVOID  = 4,  ## Must NOT be hit by a sight ray (E10). Rays that hit this
	                    ## tile mark it lit — which blocks the win condition. Rays
	                    ## pass through; cannot be placed on. Level JSON value: 4.
}


## The kind of piece occupying a tile. NONE when the tile carries no piece.
enum PieceType {
	NONE            = 0,
	OBSERVER        = 1,  ## Emits one sight ray in its facing direction.
	MIRROR_FWDSLASH = 2,  ## / orientation — redirects N↔E and S↔W.
	MIRROR_BKSLASH  = 3,  ## \ orientation — redirects N↔W and S↔E.
}


## Cardinal direction used for observer facing and ray travel.
## Values are ordered clockwise starting at North so that (dir + 1) % 4 rotates CW.
enum Direction {
	NORTH = 0,
	EAST  = 1,
	SOUTH = 2,
	WEST  = 3,
}


## Row/column deltas indexed by Direction.
## COORDINATE CONVENTION: .x = row delta, .y = col delta.
##   new_row = row + DIRECTION_DELTA[dir].x
##   new_col = col + DIRECTION_DELTA[dir].y
## This is intentional (row-major indexing) and differs from Godot screen-space
## where x is the horizontal axis. Do not mix with Vector2 screen positions.
const DIRECTION_DELTA: Array[Vector2i] = [
	Vector2i(-1,  0),  # NORTH — row decreases
	Vector2i( 0,  1),  # EAST  — col increases
	Vector2i( 1,  0),  # SOUTH — row increases
	Vector2i( 0, -1),  # WEST  — col decreases
]


## Returns [param dir] rotated 90 degrees clockwise.
static func rotate_cw(dir: Direction) -> Direction:
	return ((dir + 1) % 4) as Direction


## Returns the outgoing direction after a ray travelling [param in_dir] strikes
## a mirror of type [param piece].
##
## Reflection table:
##   / (FWDSLASH): N→E, E→N, S→W, W→S
##   \ (BKSLASH):  N→W, W→N, S→E, E→S
##
## If [param piece] is not a mirror type, [param in_dir] is returned unchanged
## (pass-through). Callers should guard against NONE/OBSERVER piece types.
static func reflect_direction(in_dir: Direction, piece: PieceType) -> Direction:
	match piece:
		PieceType.MIRROR_FWDSLASH:
			match in_dir:
				Direction.NORTH:
					return Direction.EAST
				Direction.EAST:
					return Direction.NORTH
				Direction.SOUTH:
					return Direction.WEST
				Direction.WEST:
					return Direction.SOUTH
		PieceType.MIRROR_BKSLASH:
			match in_dir:
				Direction.NORTH:
					return Direction.WEST
				Direction.WEST:
					return Direction.NORTH
				Direction.SOUTH:
					return Direction.EAST
				Direction.EAST:
					return Direction.SOUTH
	return in_dir
