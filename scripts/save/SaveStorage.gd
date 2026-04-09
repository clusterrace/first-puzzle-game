class_name SaveStorage
## Low-level platform-aware read/write backend for save data.
##
## Desktop: FileAccess writes JSON to user:// directory (OS filesystem).
## Web:     FileAccess writes to user:// (Emscripten MEMFS backed by IndexedDB)
##          then triggers an explicit IDBFS sync so data survives page reloads.
##
## Both paths use the same FileAccess API; the difference is the post-write
## JavaScriptBridge.eval call required on web to flush MEMFS → IndexedDB.
## Swap or extend this class in Sprint 2 if the web backend needs changes.

const SAVE_PATH: String = "user://save.json"


## Write [param data] as pretty-printed JSON to the save file.
## Returns true on success, false on any write error.
static func write(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveStorage: cannot open '%s' for writing (error %d)" % [
				SAVE_PATH, FileAccess.get_open_error()])
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_sync_web()
	return true


## Read and parse the save file.
## Returns an empty Dictionary on missing file or parse error; the caller
## must treat an empty result as a fresh save (no error pop-up required).
static func read() -> Dictionary:
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


## Flush Emscripten's in-memory FS to IndexedDB on web builds.
## FS.syncfs(false, cb) means "push memory → disk".
## No-op on desktop and all non-web platforms.
static func _sync_web() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("FS.syncfs(false, function(err) {})")
