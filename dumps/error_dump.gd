@tool
class_name ErrorDump extends RefCounted
## Static class that handles saving and loading of error dump files.
## Manages dump file versioning, formatting, and aggregation across game sessions.

## File used by the dump viewer. This file is only generated when running from the editor.
const LATEST_DUMP_PATH = "user://dumps/latest_dump.json"

## Reason codes for why a dump was created
enum DumpReason {
	FLUSH, ## Routine dump to disk. Do not raise an error, nothing is wrong!
	MANUAL, ## User manually requested dump
	APP_CLOSE, ## Program closed normally with debugging enabled
	WARNING, ## Warning triggered dump
	ERROR, ## Error triggered dump
	UNSPECIFIED, ## Unknown/unspecified reason
}

const RESULT_USE_BREAKPOINT = -1 # ("OK" and other error types are >= 0)
static var _save_dump_thread: Thread
static var _timer: Timer
static var _save_mutex := Mutex.new()
static var _last_dump_mutex := Mutex.new()
static var _save_processing := false
static var _save_data_ready := Semaphore.new()
## [request] = result
static var _save_dump_results := {}
static var _exiting := false

static func _static_init():
	_print("ERROR_DUMP STATIC INIT")
	_print(Engine.capture_script_backtraces()[0].format())

static func _print(...args):
	args.push_front("[t%2d|m%3d | %f] " % [
		OS.get_thread_caller_id(),
		_save_mutex.get_instance_id(),
		Time.get_ticks_usec() / 1e6])
		# "[#" + str() + "|" + str(Time.get_ticks_usec() / 1e6) + "] ")
	print.callv(args)

## Since multiple dump operations could delete the contents of the dump before a breakpoint is reached, store the last contents
static var _last_dump_string: String

class RequestBatch:
	signal done(result: int)
	## List of data arguments (see save_dump for contents)
	var list := []

static var _request_batch: RequestBatch = null
## Appends the data to the current request & returns that request
static func _append_request(data):
	_save_mutex.lock()
	if not _request_batch:
		_request_batch = RequestBatch.new()
	_request_batch.list.append(data)
	_save_mutex.unlock()
	return _request_batch

## Saves a dump to the current session's dump file
## If no session file exists, creates a new one
## [param on_failure] Receives the encountered error type
static func save_dump(logger_data: Dictionary, reason := DumpReason.UNSPECIFIED, context := "", on_failure: Callable = Callable()):
	var data = {
		"logger_data": logger_data,
		"reason": reason,
		"context": context,
		"dump_dict": create_dump_dict(logger_data, reason, context),
	}
	var request = _append_request(data)

	if not _save_dump_thread:
		_save_dump_thread = Thread.new()
		_save_dump_thread.start(_save_dump_thread_loop)

		var game_window: Window = Engine.get_main_loop().root.get_window()
		_timer = Timer.new()
		_timer.ignore_time_scale = true
		_timer.wait_time = 0.01
		game_window.add_child(_timer)
		_timer.connect("timeout", _timer_callback)
		game_window.tree_exited.connect(func():
			_print("TREE_EXITING")
			_save_cleanup())
		game_window.tree_exiting.connect(func():
			_print("TREE_EXITED")
			_save_cleanup())
		game_window.close_requested.connect(func():
			_print("CLOSE_REQUESTED")
			_save_cleanup())
	_save_data_ready.post()
	_timer.start()

	var result = await request.done
	if result > OK:
		on_failure.call(result)
	if result != OK and not _exiting:
		_print("breakpoint ", OS.get_thread_caller_id())
		breakpoint
		_print("after breakpoint ", OS.get_thread_caller_id())

static func _timer_callback():
	if not _save_processing:
		_timer.stop()
	if _save_dump_results.is_empty():
		return
	_print("_timer_callback got results. exiting: ", _exiting)
	_save_mutex.lock()
	for request in _save_dump_results:
		var result = _save_dump_results[request]
		request.done.emit(result)
	_save_dump_results.clear()
	_save_mutex.unlock()

static func _save_cleanup():
	_print("cleanup0")
	if not _save_dump_thread:
		_print("cleanup return early")
		return
	_save_mutex.lock()
	_exiting = true
	_save_mutex.unlock()
	_save_data_ready.post()
	_print("cleanup1")
	_save_dump_thread.wait_to_finish()
	_print("cleanup2")

static func _save_dump_thread_loop():
	while true:
		_save_data_ready.wait()

		var should_exit = _exiting
		if should_exit:
			return

		_save_mutex.lock()
		var request = _request_batch
		if not request:
			# Empty out semaphore (since semaphore is increased for every item queued)
			while _save_data_ready.try_wait():
				pass
			_save_mutex.unlock()
			continue
		_request_batch = RequestBatch.new()
		_save_processing = true
		_print("_save_processing = true")
		_save_mutex.unlock()

		var result = _save_dump_threaded_main(request)

		_save_mutex.lock()
		_save_dump_results[request] = result
		_save_processing = false
		_print("_save_processing = false")
		_save_mutex.unlock()

static func _save_dump_threaded_main(request: RequestBatch) -> Error:
	_ensure_dumps_directory()

	# Handle session file
	var session_path: String = Print.current_dump_file
	var is_first: bool
	var file: FileAccess
	if session_path.is_empty():
		session_path = _generate_session_file_path()
		Print.current_dump_file = session_path

		# Create new file with opening bracket
		file = FileAccess.open(session_path, FileAccess.WRITE)
		if not file:
			push_error("Failed to create session dump file: " + session_path)
			return ERR_CANT_CREATE
		is_first = true
	else:
		# Append to existing file
		file = FileAccess.open(session_path, FileAccess.READ_WRITE)
		if not file:
			push_error("Failed to open session dump file: " + session_path)
			return ERR_FILE_CANT_OPEN

		# Seek to just before the last two characters (the newline and closing bracket)
		file.seek(file.get_length() - 2)
		is_first = false

	var use_breakpoint = false
	for data in request.list:
		var logger_data = data.logger_data
		var reason = data.reason
		var context = data.context
		var dump_dict = data.dump_dict

		_print("dealing with data ", reason, " | ", context, " | ")

		_append_to_file(file, dump_dict, is_first)
		is_first = false

		# Mirror to latest dump file if we're in the editor.
		if OS.has_feature("editor") and reason >= DumpReason.APP_CLOSE:
			# Copy the entire session file to latest_dump
			var session_file = FileAccess.open(session_path, FileAccess.READ)
			_print("LOCKING LAST_DUMP_MUTEX")
			_last_dump_mutex.lock()
			var latest_file = FileAccess.open(LATEST_DUMP_PATH, FileAccess.WRITE)

			_print("stage1")

			if session_file and latest_file:
				_print("stage2")
				var now = Time.get_ticks_msec()
				while Time.get_ticks_msec() - now <= 1000:
					pass
				_last_dump_string = session_file.get_as_text()
				_print("store: ", latest_file.store_string(_last_dump_string))
				latest_file.flush()
				_print("after flush")
				latest_file.close()
				_print("stage3")
				session_file.close()
				_print("stage4")

				# Pause execution and load the dump in the editor immediately.
				if reason >= DumpReason.WARNING:
					use_breakpoint = true
			_print("unlocking LAST_DUMP_MUTEX")
			_last_dump_mutex.unlock()

		if reason == DumpReason.MANUAL:
			_print("show_dbg_window")
			show_debug_window(session_path)
			_print("after show_dbg_window")

	return RESULT_USE_BREAKPOINT if use_breakpoint else OK


# Temporary debug function to show the _print editor tab in a window
static func show_debug_window(session_path: String) -> void:
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
	window.min_size = Vector2i(400, 300) # Set minimum size
	window.max_size = Vector2i(0, 0) # No maximum size (0,0 means unlimited)
	window.mode = Window.MODE_WINDOWED # Start in windowed mode
	window.borderless = false
	#window.always_on_top = true  # Keep above game window
	window.transparent = false
	window.close_requested.connect(func(): window.queue_free())

	# Load and add _print editor tab
	_print("trying to load crash_report")
	var crash_report = load("res://addons/sdg-_print/dumps/crash_report.tscn")
	_print("after trying to load crash_report")
	var editor_tab = crash_report.instantiate()
	window.add_child(editor_tab)

	# Make editor tab fill window
	editor_tab.anchors_preset = Control.PRESET_FULL_RECT

	# Add window to scene tree
	Engine.get_main_loop().root.add_child(window)

	# Load the latest dump
	_print("load latest dump1")
	_print("load latest dump result: ", editor_tab.load_latest_dump(session_path))
	_print("load latest dump2")


static func paths_equal(a: String, b: String) -> bool:
	return ProjectSettings.globalize_path(a).simplify_path() == ProjectSettings.globalize_path(b).simplify_path()

## Loads and validates all dumps from a file
## Returns an array of DumpData objects, skipping any that fail validation
static func load_dumps(file_path: String) -> Array[DumpData]:
	_print("load_dumps1")

	var file_content: String
	var is_latest = paths_equal(file_path, LATEST_DUMP_PATH)
	var have_lock := false
	if is_latest:
		# have_lock = _last_dump_mutex.try_lock()
		have_lock = true
		_print("before lock")
		_last_dump_mutex.lock() # todo tmp
		_print("after lock")

		_print("have lock? ", have_lock)
		if not have_lock:
			if not _last_dump_string:
				return []
			file_content = _last_dump_string
			_print("using _last_dump_string, length: ", _last_dump_string.length())
		else:
			_print("no mutex lock so should be able to load normally")

	_print("load_dumps2. file_content length: ", file_content.length())

	var inner = func():
		if not file_content:
			if not FileAccess.file_exists(file_path):
				push_error("Dump file not found: " + file_path)
				return []

			var file = FileAccess.open(file_path, FileAccess.READ)
			if not file:
				push_error("Failed to open dump file: " + file_path)
				return []
			file_content = file.get_as_text()

	var result = inner.call()
	if have_lock:
		print(">>UNLOCKING _last_dump_mutex")
		_last_dump_mutex.unlock()
	if result != null:
		return result

	_print("load_dumps3")
	_print(file_content)

	var json = JSON.new()
	var parse_result = json.parse(file_content)
	if parse_result != OK:
		push_error("Failed to parse dump file: " + json.get_error_message())
		return []

	var dumps = json.get_data()
	if not dumps is Array:
		push_error("Invalid dump file format - expected array of dumps")
		return []

	_print("load_dumps4")

	var dump_data: Array[DumpData] = []
	for idx in dumps.size():
		var dump_dict = dumps[idx]
		var dump = DumpData.new()
		dump.dump_index = idx + 1
		if dump.load_from_dict(dump_dict):
			dump_data.append(dump)

	_print("load_dumps5")
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

func _notification(msg):
	if msg != NOTIFICATION_PREDELETE:
		return
