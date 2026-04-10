class_name SaveStorage
## Low-level platform-aware read/write backend for save data.
##
## Desktop: FileAccess writes JSON to user:// directory (OS filesystem).
## Web:     JavaScriptBridge writes JSON directly to localStorage.
##          Key: WEB_STORAGE_KEY. Safe for typical save data sizes (<5 KB).
##
## Platform detection uses OS.has_feature("web") so desktop editor runs always
## use the file backend even when targeting web export.

const SAVE_PATH: String = "user://save.json"
const WEB_STORAGE_KEY: String = "sight_lines_save"


## Write [param data] as JSON to platform storage.
## Returns true on success, false on any write error.
static func write(data: Dictionary) -> bool:
	if OS.has_feature("web"):
		return _write_web(data)
	return _write_desktop(data)


## Read and parse saved data from platform storage.
## Returns an empty Dictionary on missing save or parse error; the caller
## must treat an empty result as a fresh save (no error pop-up required).
static func read() -> Dictionary:
	if OS.has_feature("web"):
		return _read_web()
	return _read_desktop()


# ── Desktop ───────────────────────────────────────────────────────────────────

static func _write_desktop(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveStorage: cannot open '%s' for writing (error %d)" % [
				SAVE_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


static func _read_desktop() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveStorage: cannot open '%s' for reading (error %d)" % [
				SAVE_PATH, FileAccess.get_open_error()])
		return {}

	var raw: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_error("SaveStorage: save file is not a valid JSON object — treating as fresh start")
		return {}

	return parsed as Dictionary


# ── Web (localStorage) ────────────────────────────────────────────────────────

## Store [param data] to localStorage via JavaScriptBridge.
## JSON.stringify on a GDScript String produces a properly-escaped JS string
## literal, making the eval injection-safe for arbitrary save data content.
static func _write_web(data: Dictionary) -> bool:
	var json_str: String = JSON.stringify(data)
	JavaScriptBridge.eval(
			"localStorage.setItem('%s', %s)" % [WEB_STORAGE_KEY, JSON.stringify(json_str)])
	return true


## Read saved data from localStorage via JavaScriptBridge.
## localStorage.getItem returns null (JS) when the key is absent, which
## JavaScriptBridge maps to GDScript null.
static func _read_web() -> Dictionary:
	var raw: Variant = JavaScriptBridge.eval(
			"localStorage.getItem('%s')" % WEB_STORAGE_KEY)
	if raw == null:
		return {}
	var json_str: String = str(raw)
	if json_str.is_empty() or json_str == "null":
		return {}

	var parsed: Variant = JSON.parse_string(json_str)
	if not parsed is Dictionary:
		push_error("SaveStorage: localStorage data is not valid JSON — treating as fresh start")
		return {}

	return parsed as Dictionary
