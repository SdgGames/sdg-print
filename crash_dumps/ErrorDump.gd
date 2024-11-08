class_name ErrorDump extends RefCounted
## Static class that handles saving and loading of error dump files.
## Manages dump file versioning, formatting, and aggregation across game sessions.

## Current version of the dump file format
const DUMP_FILE_VERSION = 1

## Reason codes for why a dump was created
enum DumpReason {
	MANUAL = 0,  ## User manually requested dump
	ERROR = 1,   ## Error triggered dump
	ASSERT = 2,  ## Assert failure triggered dump
	SIGNAL = 3,  ## Signal handler triggered dump
	UNKNOWN = 99 ## Unknown/unspecified reason
}


## Format a reason code into a human-readable string
static func _reason_to_string(reason: DumpReason) -> String:
	return DumpReason.keys()[reason].capitalize()


## Generates a dump file path for the current game session
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


## Ensures the dumps directory exists
static func _ensure_dumps_directory() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("dumps"):
		dir.make_dir("dumps")


## Creates a standardized dump dictionary with metadata
static func _create_dump_dict(logger_data: Dictionary, reason: DumpReason) -> Dictionary:
	return {
		"version": DUMP_FILE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"reason": _reason_to_string(reason),
		"loggers": logger_data
	}


## Saves a dump to the current session's dump file
## If no session file exists, creates a new one
static func save_dump(logger_data: Dictionary, reason: DumpReason = DumpReason.UNKNOWN) -> Error:
	# Make sure we have a dumps directory
	_ensure_dumps_directory()
	
	# Get or create session file path
	var session_path: String = Print.current_dump_file
	if session_path.is_empty():
		session_path = _generate_session_file_path()
		Print.current_dump_file = session_path
	
	# Create the standardized dump dictionary
	var dump_dict = _create_dump_dict(logger_data, reason)
	
	# Load existing dumps if file exists
	var dumps: Array = []
	if FileAccess.file_exists(session_path):
		var existing_file = FileAccess.open(session_path, FileAccess.READ)
		if existing_file:
			var json = JSON.new()
			var parse_result = json.parse(existing_file.get_as_text())
			if parse_result == OK:
				dumps = json.get_data()
	
	# Add new dump
	dumps.append(dump_dict)
	
	# Save updated dumps array
	var file = FileAccess.open(session_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open dump file for writing: " + session_path)
		return Error.ERR_CANT_CREATE
	
	file.store_string(JSON.stringify(dumps, "\t"))
	return OK


## Loads and validates all dumps from a file
## Returns an array of valid dumps, skipping any that fail version validation
static func load_dumps(file_path: String) -> Array:
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
	
	# Filter out dumps with incompatible versions
	var valid_dumps: Array = []
	for dump in dumps:
		if not dump is Dictionary:
			push_warning("Skipping invalid dump entry - not a dictionary")
			continue
		
		if not dump.has("version"):
			push_warning("Skipping dump without version info")
			continue
		
		if dump.version != DUMP_FILE_VERSION:
			push_warning("Skipping incompatible dump version: %d" % dump.version)
			continue
		
		valid_dumps.append(dump)
	
	return valid_dumps


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
