# TestSaveSystem.gd — headless unit tests for the save/load layer (KAMA-22).
#
# Run via:  godot --headless --script tests/TestSaveSystem.gd
#
# Tests SaveData serialisation round-trips and graceful error paths.
# SaveStorage is not exercised directly (filesystem I/O in headless is awkward);
# integration with the real user:// path is validated by playing the game and
# restarting.

extends SceneTree

func _init() -> void:
	_run_all()
	quit(0)


func _run_all() -> void:
	var passed: int = 0
	var failed: int = 0

	for test_name: String in _tests():
		var result: bool = call(test_name)
		if result:
			print("  PASS  %s" % test_name)
			passed += 1
		else:
			print("  FAIL  %s" % test_name)
			failed += 1

	print("\n%d passed, %d failed" % [passed, failed])
	if failed > 0:
		OS.exit_code = 1


func _tests() -> Array[String]:
	return [
		"test_savedata_round_trip",
		"test_savedata_empty_flags",
		"test_savedata_unsupported_version_returns_null",
		"test_savedata_corrupt_flags_field_ignored",
		"test_savedata_idempotent_mark",
	]


# ── SaveData round-trip ───────────────────────────────────────────────────────

func test_savedata_round_trip() -> bool:
	var original := SaveData.new()
	original.completed_levels["level_0"] = true
	original.completed_levels["level_1"] = false

	var d: Dictionary = original.to_dict()
	var loaded: SaveData = SaveData.from_dict(d)

	if loaded == null:
		return false
	if not loaded.completed_levels.get("level_0", false):
		return false
	if loaded.completed_levels.get("level_1", true):  # should be false
		return false
	return true


func test_savedata_empty_flags() -> bool:
	var data: Dictionary = {"version": 1, "completed_levels": {}}
	var loaded: SaveData = SaveData.from_dict(data)
	return loaded != null and loaded.completed_levels.is_empty()


func test_savedata_unsupported_version_returns_null() -> bool:
	var data: Dictionary = {"version": 99, "completed_levels": {}}
	var loaded: SaveData = SaveData.from_dict(data)
	return loaded == null


func test_savedata_corrupt_flags_field_ignored() -> bool:
	# completed_levels is not a Dictionary — should be silently ignored.
	var data: Dictionary = {"version": 1, "completed_levels": "corrupt_string"}
	var loaded: SaveData = SaveData.from_dict(data)
	return loaded != null and loaded.completed_levels.is_empty()


func test_savedata_idempotent_mark() -> bool:
	var save := SaveData.new()
	save.completed_levels["level_0"] = true
	var d: Dictionary = save.to_dict()
	# Verify that bool(true) round-trips correctly.
	var reloaded: SaveData = SaveData.from_dict(d)
	if reloaded == null:
		return false
	return reloaded.completed_levels.get("level_0", false) == true
