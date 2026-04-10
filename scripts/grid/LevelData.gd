class_name LevelData
## Immutable authored level data loaded from a JSON file.
## Describes the grid layout and the player's starting piece inventory.
## Runtime mutable state lives in GridState, not here.
##
## JSON file format (version 1):
## {
##   "version": 1,
##   "title": "Level 1 — Line of Sight",
##   "rows": 6,
##   "cols": 7,
##   "grid": [
##     [1, 1, 1, 1, 1, 1, 1],
##     [1, 2, 0, 0, 0, 3, 1],
##     ...
##   ],
##   "fixed_pieces": [
##     { "row": 3, "col": 1, "piece_type": 1, "direction": 1 }
##   ],
##   "player_inventory": [1, 2]
## }
##
## TileType values:  0=EMPTY  1=WALL  2=SLOT  3=TARGET  4=TARGET_AVOID (E10)
## PieceType values: 0=NONE   1=OBSERVER  2=MIRROR_FWDSLASH  3=MIRROR_BKSLASH
## Direction values: 0=NORTH  1=EAST  2=SOUTH  3=WEST
## TARGET_AVOID (4): must-not-light cell — ray hits mark it lit, blocking win.


const SUPPORTED_VERSION: int = 1


## Display name shown in the HUD.
var title: String = ""

## Grid dimensions.
var rows: int = 0
var cols: int = 0

## Flat row-major array of TileType int values. Index = row * cols + col.
## Populated by load_from_file / from_dict; never modified after construction.
var tile_grid: Array = []  # Array[int], TileType values

## Fixed (pre-placed, immovable) pieces. Each entry is a Dictionary with keys:
##   row (int), col (int), piece_type (int), direction (int)
var fixed_pieces: Array = []  # Array[Dictionary]

## Piece types the player starts with. Each value is a PieceType int.
## Initial facing direction for placed pieces defaults to EAST.
var player_inventory: Array = []  # Array[int], PieceType values


## Loads a LevelData from a JSON file at [param path].
## Returns null and emits push_error on failure.
static func load_from_file(path: String) -> LevelData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("LevelData: cannot open '%s' (error %d)" % [path, FileAccess.get_open_error()])
		return null

	var raw: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_error("LevelData: '%s' is not a valid JSON object" % path)
		return null

	return LevelData.from_dict(parsed as Dictionary)


## Constructs a LevelData from a parsed JSON Dictionary.
## Returns null and emits push_error if the dict is malformed or unsupported.
static func from_dict(data: Dictionary) -> LevelData:
	var version: int = int(data.get("version", 0))
	if version != SUPPORTED_VERSION:
		push_error("LevelData: unsupported version %d (expected %d)" % [version, SUPPORTED_VERSION])
		return null

	var level := LevelData.new()
	level.title = str(data.get("title", "Untitled"))
	level.rows  = int(data.get("rows",  0))
	level.cols  = int(data.get("cols",  0))

	if level.rows <= 0 or level.cols <= 0:
		push_error("LevelData: rows and cols must be positive integers")
		return null

	# Parse and flatten the 2D grid array.
	var raw_grid: Array = data.get("grid", []) as Array
	if raw_grid.size() != level.rows:
		push_error("LevelData: grid has %d rows but rows=%d" % [raw_grid.size(), level.rows])
		return null

	level.tile_grid.resize(level.rows * level.cols)
	for r: int in range(level.rows):
		var row: Array = raw_grid[r] as Array
		if row.size() != level.cols:
			push_error("LevelData: row %d has %d cols but cols=%d" % [r, row.size(), level.cols])
			return null
		for c: int in range(level.cols):
			level.tile_grid[r * level.cols + c] = int(row[c])

	# Parse fixed pieces.
	for fp: Variant in data.get("fixed_pieces", []) as Array:
		var d: Dictionary = fp as Dictionary
		level.fixed_pieces.append({
			"row":        int(d.get("row",        0)),
			"col":        int(d.get("col",        0)),
			"piece_type": int(d.get("piece_type", 0)),
			"direction":  int(d.get("direction",  0)),
		})

	# Parse player inventory.
	for item: Variant in data.get("player_inventory", []) as Array:
		level.player_inventory.append(int(item))

	return level
