extends Node
## Autoload singleton: manages the Sight Lines level sequence.
##
## Registered in project.godot:
##   [autoload]
##   LevelManager="*res://scripts/LevelManager.gd"
##
## Usage:
##   LevelManager.current_index = 2
##   var data := LevelManager.load_level_data(LevelManager.current_index)
##   var level_id := LevelManager.get_level_id(LevelManager.current_index)


## Ordered list of level file paths. Sprint 1: linear sequence, no branching.
const LEVEL_PATHS: Array[String] = [
	"res://levels/level_01.json",
	"res://levels/level_02.json",
	"res://levels/level_03.json",
	"res://levels/level_04.json",
	"res://levels/level_05.json",
]

## Index of the currently active level (0-based).
var current_index: int = 0


## Total number of levels in the sequence.
func get_level_count() -> int:
	return LEVEL_PATHS.size()


## Save-system key for level at [param index]: "level_01" through "level_05".
## Matches SaveManager.mark_level_complete / is_level_complete.
func get_level_id(index: int) -> String:
	return "level_%02d" % (index + 1)


## Load and return a fresh LevelData for [param index].
## Returns null and emits push_error on file or parse failure.
func load_level_data(index: int) -> LevelData:
	if index < 0 or index >= LEVEL_PATHS.size():
		push_error("LevelManager.load_level_data: index %d out of range (0..%d)" % [
			index, LEVEL_PATHS.size() - 1])
		return null
	return LevelData.load_from_file(LEVEL_PATHS[index])


## Returns true when [param index] is the final level in the sequence.
func is_last_level(index: int) -> bool:
	return index >= LEVEL_PATHS.size() - 1


## Returns the index of the first incomplete level, or the last index when
## all levels are complete. Useful for setting the level-select default cursor.
func first_incomplete_index() -> int:
	for i: int in range(LEVEL_PATHS.size()):
		if not SaveManager.is_level_complete(get_level_id(i)):
			return i
	return LEVEL_PATHS.size() - 1
