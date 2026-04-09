## Autoload singleton. Single access point for level completion persistence.
##
## Registered in project.godot:
##   [autoload]
##   SaveManager="*res://scripts/save/SaveManager.gd"
##
## Usage:
##   SaveManager.mark_level_complete("level_0")
##   var done: bool = SaveManager.is_level_complete("level_0")
##
## Load happens automatically in _ready(). Missing or corrupt save files are
## silently treated as a fresh start — no error dialog is shown to the player.

extends Node

## Emitted when a level transitions from incomplete to complete.
## Not emitted for redundant mark_level_complete calls on an already-done level.
signal level_completed(level_id: String)

var _data: SaveData = SaveData.new()


func _ready() -> void:
	_load()


## Mark [param level_id] as complete and flush to storage immediately.
## Idempotent: calling again on an already-complete level is a safe no-op.
func mark_level_complete(level_id: String) -> void:
	if _data.completed_levels.get(level_id, false):
		return
	_data.completed_levels[level_id] = true
	_flush()
	level_completed.emit(level_id)


## Returns true if [param level_id] has been completed in a prior session or
## the current session.
func is_level_complete(level_id: String) -> bool:
	return _data.completed_levels.get(level_id, false)


## Returns a copy of the full completion map (level_id -> bool).
## Suitable for hub / level-select UI iteration.
func get_all_completed() -> Dictionary:
	return _data.completed_levels.duplicate()


# ── Internal ──────────────────────────────────────────────────────────────────

func _flush() -> void:
	if not SaveStorage.write(_data.to_dict()):
		push_error("SaveManager: flush failed — progress may not be persisted this session")


func _load() -> void:
	var raw: Dictionary = SaveStorage.read()
	if raw.is_empty():
		# Missing file or corrupt JSON — start fresh, no error surfaced to player.
		_data = SaveData.new()
		return
	var loaded: SaveData = SaveData.from_dict(raw)
	_data = loaded if loaded != null else SaveData.new()
