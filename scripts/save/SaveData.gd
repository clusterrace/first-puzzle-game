class_name SaveData
## Persistent player data: boolean completion flag per level.
## Serialised to / from a JSON-compatible dictionary.

const CURRENT_VERSION: int = 1

## Maps level ID strings to completion status.
## e.g. {"level_0": true, "level_1": false}
var completed_levels: Dictionary = {}  # String -> bool


## Deserialise from a parsed JSON dictionary.
## Returns null if the version is unsupported or the data is malformed;
## the caller must treat null as a fresh start.
static func from_dict(data: Dictionary) -> SaveData:
	var version: int = int(data.get("version", 0))
	if version != CURRENT_VERSION:
		push_error("SaveData: unsupported version %d (expected %d)" % [version, CURRENT_VERSION])
		return null

	var save := SaveData.new()
	var raw_flags: Variant = data.get("completed_levels", {})
	if raw_flags is Dictionary:
		for key: Variant in raw_flags:
			save.completed_levels[str(key)] = bool(raw_flags[key])
	return save


## Serialise to a JSON-compatible dictionary suitable for FileAccess storage.
func to_dict() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"completed_levels": completed_levels.duplicate(),
	}
