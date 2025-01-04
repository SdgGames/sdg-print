class_name ErrorDump extends RefCounted
## Static class that handles saving and loading of error dump files.
## Manages dump file versioning, formatting, and aggregation across game sessions.

## File used by the dump viewer. This file is only generated when running from the editor.
const LATEST_DUMP_PATH = "user://dumps/latest_dump.json"

## Reason codes for why a dump was created
enum DumpReason {
	FLUSH,      ## Routine dump to disk. Do not raise an error, nothing is wrong!
	MANUAL,     ## User manually requested dump
	ERROR,      ## Error triggered dump
	APP_CLOSE,  ## Program closed normally with debugging enabled
	UNSPECIFIED ## Unknown/unspecified reason
}


## Saves a dump to the current session's dump file
## If no session file exists, creates a new one
static func save_dump(logger_data: Dictionary, reason := DumpReason.UNSPECIFIED, context := "") -> Error:
	_ensure_dumps_directory()
	
	# Create the dump dictionary once
	var dump_dict = create_dump_dict(logger_data, reason, context)
	
	# Handle session file
	var session_path: String = Print.current_dump_file
	if session_path.is_empty():
		session_path = _generate_session_file_path()
		Print.current_dump_file = session_path
		
		# Create new file with opening bracket
		var file = FileAccess.open(session_path, FileAccess.WRITE)
		if not file:
			push_error("Failed to create session dump file: " + session_path)
			return ERR_CANT_CREATE
		_append_to_file(file, dump_dict, true)
	else:
		# Append to existing file
		var file = FileAccess.open(session_path, FileAccess.READ_WRITE)
		if not file:
			push_error("Failed to open session dump file: " + session_path)
			return ERR_FILE_CANT_OPEN
		
		# Seek to just before the last two characters (the newline and closing bracket)
		file.seek(file.get_length() - 2)
		_append_to_file(file, dump_dict, false)
	
	# Mirror to latest dump file if we're in the editor
	if OS.has_feature("editor"):
		# Copy the entire session file to latest_dump
		var session_file = FileAccess.open(session_path, FileAccess.READ)
		var latest_file = FileAccess.open(LATEST_DUMP_PATH, FileAccess.WRITE)
		
		if session_file and latest_file:
			latest_file.store_string(session_file.get_as_text())
			latest_file.close()
			session_file.close()
			
			# Only trigger debug window for non-close events
			if reason != DumpReason.APP_CLOSE and reason != DumpReason.FLUSH:
				# Trigger a breakpoint after writing the file. This will cause the editor to open
				# the Print panel and display the dump that we just generated.
				#TODO: move back to editor once we are done developing in the game window.
				#breakpoint
				show_debug_window()
	
	return OK


# Temporary debug function to show the print editor tab in a window
static func show_debug_window() -> void:
	# Create window
	var window = Window.new()
	window.title = "Print Debug Viewer"
	
	# Get the game window size and position
	var game_window = Engine.get_main_loop().root.get_window()
	var screen_size = DisplayServer.screen_get_size()
	
	# Set size to 95% of game window size
	window.size = Vector2i(
		int(game_window.size.x * 0.95),
		int(game_window.size.y * 0.95)
	)
	
	# Center on screen
	window.position = Vector2i(
		(screen_size.x - window.size.x) / 2,
		(screen_size.y - window.size.y) / 2
	)
	
	# Enable window features
	window.unresizable = false
	window.min_size = Vector2i(400, 300)  # Set minimum size
	window.max_size = Vector2i(0, 0)  # No maximum size (0,0 means unlimited)
	window.mode = Window.MODE_WINDOWED  # Start in windowed mode
	window.borderless = false
	#window.always_on_top = true  # Keep above game window
	window.transparent = false
	window.close_requested.connect(func(): window.queue_free())
	
	# Load and add print editor tab
	var crash_report = load("res://addons/sdg-print/dumps/crash_report.tscn")
	var editor_tab = crash_report.instantiate()
	window.add_child(editor_tab)
	
	# Make editor tab fill window
	editor_tab.anchors_preset = Control.PRESET_FULL_RECT
	
	# Add window to scene tree
	Engine.get_main_loop().root.add_child(window)
	
	# Load the latest dump
	editor_tab.load_latest_dump(LATEST_DUMP_PATH)


## Loads and validates all dumps from a file
## Returns an array of DumpData objects, skipping any that fail validation
static func load_dumps(file_path: String) -> Array[DumpData]:
	if not FileAccess.file_exists(file_path):
		push_error("Dump file not found: " + file_path)
		return []
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open dump file: " + file_path)
		return []
	
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	if parse_result != OK:
		push_error("Failed to parse dump file: " + json.get_error_message())
		return []
	
	var dumps = json.get_data()
	if not dumps is Array:
		push_error("Invalid dump file format - expected array of dumps")
		return []
	
	var dump_data: Array[DumpData] = []
	for dump_dict in dumps:
		var dump = DumpData.new()
		if dump.load_from_dict(dump_dict):
			dump_data.append(dump)
	
	return dump_data


## Lists all dump files in the dumps directory
static func list_dump_files() -> Array[String]:
	_ensure_dumps_directory()
	
	var files: Array[String] = []
	var dir = DirAccess.open("user://dumps")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				files.append("user://dumps/" + file_name)
			file_name = dir.get_next()
	
	return files


## Cleans up old dump files, keeping only the specified number of most recent files
static func cleanup_old_dumps(keep_count: int = 10) -> void:
	var files = list_dump_files()
	files.sort() # Timestamp in filename ensures chronological order
	
	if files.size() <= keep_count:
		return
	
	for i in range(files.size() - keep_count):
		var file_path = files[i]
		var dir = DirAccess.open("user://dumps")
		if dir:
			dir.remove(file_path)


## Creates a standardized dump dictionary with metadata
static func create_dump_dict(logger_data: Dictionary, reason: DumpReason, context := "") -> Dictionary:
	var reason_string = DumpReason.keys()[reason].capitalize()
	if context != "":
		reason_string += " - " + context
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"reason": reason_string,
		"module_width": Print._current_module_width,
		"loggers": logger_data
	}


# Generates a dump file path for the current game session
static func _generate_session_file_path() -> String:
	var datetime = Time.get_datetime_dict_from_system()
	var file_name = "error_dump_%d%02d%02d_%02d%02d%02d.json" % [
		datetime.year,
		datetime.month,
		datetime.day,
		datetime.hour,
		datetime.minute,
		datetime.second
	]
	return "user://dumps/" + file_name


# Add this dump to the current file. Add the appropriate punctuation for the array.
static func _append_to_file(file: FileAccess, dump_dict: Dictionary, is_first: bool) -> void:
	var json_str = JSON.stringify(dump_dict, "\t")
	if is_first:
		file.store_string("[\n" + json_str + "\n]")
	else:
		file.store_string(",\n" + json_str + "\n]")


# Ensures the dumps directory exists
static func _ensure_dumps_directory() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("dumps"):
		dir.make_dir("dumps")
