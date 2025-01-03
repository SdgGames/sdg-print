@icon("res://addons/sdg-print/logger/Logger_icon.svg")
class_name Logger extends Node
## More advanced print class that logs events, warnings, and errors for a particular subsystem.
##
## A logging helper for a module or individual object.
## Can print to the standard output ([code]print()[/code]) and to the in-game console (if present).
## The output verbosity can be changed by setting [member print_level] or [member archive_level].
## [br][br]
## If a module's [member print_level] is set to [enum LogLevel.SILENT] nothing will be printed to
## the console, but messages will still be saved to a buffer. If an error is encountered
## (the call might look like: [code]my_logger.error("Something went wrong")[/code]),
## the entire saved buffer will be printed. You can call [method start] to clear the buffer if you
## want to reset the message buffer (starting a new game, loading a new file, etc.).
## [br][br]
## The logger provides a convenient interface for tracking data within a single frame across two 
## levels: a title level for high-level state information, and a detailed level for specifics.
## Use [method start_frame] to clear the previous frame's data. Then, use [method set_frame_title]
## to build up the title string (e.g., "AI: Patrolling | Target: Player") and [method in_frame] to 
## log detailed information line by line. Finally, use [method end_frame] to indicate that the frame
## data is fully written.


## Defines the level that each print is recorded at, or archived at.
## If the print level is higher (more verbose) than [member print_level], then nothing will be
## output. Similarly, if the print level is higher than [member archive_level], the print will be
## lost, and will not appear in the output dump for [method error] calls.
enum LogLevel {
	SILENT = 0, ## Mutes all prints. Not intended for use in [method print_at_level] calls.
	ERROR = 1, ## Prints an error using [code]push_error[/code].
	WARNING = 2, ## Prints a warning using [code]push_warning[/code].
	INFO = 3, ## Standard print formatted as "[color=cyan]INFO:[/color] message".
	DEBUG = 4, ## Standard print formatted as "[color=green]DEBUG:[/color] message".
	VERBOSE = 5 ## Standard print formatted as "[color=purple]VERBOSE:[/color] message".
}

## Determines if this logger is a member of the Print singleton, a instanced node, or unknown.
enum LogType {
	SINGLETON,
	OBJECT,
	UNKNOWN
}

## Custom ID that appears in logs for this module. This must be unique, registration will
## fail if there are multiple loggers with the same id.
## [br][br]
## If left blank, will be set automatically based on the parent's path in the scene tree.
@export var id := ""

## What [enum LogLevel] the module will print at. Messages more verbose than this won't be output.
@export var print_level : LogLevel = LogLevel.SILENT

## What [enum LogLevel] the module will archive. Messages more verbose than this won't appear in error dumps.
@export var archive_level : LogLevel = LogLevel.DEBUG

## Settings controlling the format and appearance of log messages.
@export var settings: PrintSettings

# Internal variables
var _log_type : LogType = LogType.OBJECT
var _console = null

# Storage for log entries and frame logs
var _log_history: RingBuffer
var _frame_history: RingBuffer
var _current_frame: FrameLog
var _has_frame_changes := false


# Register with the Print singleton when ready.
# If this logger is a child of an existing node, will update the ID accordingly.
func _ready():
	if id == "":
		id = str(get_parent().get_path()).replace("/root/", "")
	Print._register_logger(self)
	start()


# Set up everything that we can't do in an _init call (because Godot calls _init on nodes in the scene tree).
# Returns self so you can chain Logger.new.init(...)
func _second_init(id := "", print_level := LogLevel.VERBOSE, archive_level := LogLevel.VERBOSE,
		log_type := LogType.OBJECT, custom_settings: PrintSettings = null) -> Logger:
	self.id = id
	self.name = str(id)
	self.print_level = print_level
	self.archive_level = archive_level
	self._log_type = log_type
	self.settings = custom_settings if custom_settings else Print.settings
	
	# Initialize our history buffers
	_log_history = RingBuffer.new(settings.max_log_entries)
	_frame_history = RingBuffer.new(settings.max_frames)
	return self


## Clears the message and frame history for this logger instance.
func start():
	_log_history.clear()
	_frame_history.clear()
	_current_frame = null
	_has_frame_changes = false


## Throws an error if the statement is false.
## Also throws an assert so program execution will halt.
func assert_that(is_true, message := ""):
	if !is_true:
		error(message, false, true)
		assert(false)


## Prints an error to screen and pushes to console.
## By default, this will create an error dump as well.
## If you just want to print the current error, set [param dump_error] to [code]false[/code].
func error(message: String, dump_error := true, dump_all := false):
	Print.error_count += 1
	var entry = _log(LogLevel.ERROR, message)
	
	if print_level >= LogLevel.ERROR:
		var formatted = entry.format(settings)
		_print_console(formatted)
		push_error(message)
		if dump_all:
			Print.dump_all(ErrorDump.DumpReason.ERROR)
		elif dump_error:
			error_dump()


## Prints a WARNING to screen and pushes to console.
func warning(message: String):
	Print.warning_count += 1
	var entry = _log(LogLevel.WARNING, message)
	
	if print_level >= LogLevel.WARNING:
		var formatted = entry.format(settings)
		_print_console(formatted)
		push_warning(message)
		if OS.has_feature("editor"):
			print_rich(formatted)


## Prints an INFO message to screen and console.
func info(message: String):
	var entry = _log(LogLevel.INFO, message)
	
	if print_level >= LogLevel.INFO:
		var formatted = entry.format(settings)
		_print_console(formatted)
		print_rich(formatted)


## Prints a DEBUG message to screen and console.
func debug(message: String):
	var entry = _log(LogLevel.DEBUG, message)
	
	if print_level >= LogLevel.DEBUG:
		var formatted = entry.format(settings)
		_print_console(formatted)
		print_rich(formatted)


## Prints a VERBOSE message to screen and console.
func verbose(message: String):
	var entry = _log(LogLevel.VERBOSE, message)
	
	if print_level >= LogLevel.VERBOSE:
		var formatted = entry.format(settings)
		_print_console(formatted)
		print_rich(formatted)


## Clears the previous frame's data and prepares for a new frame capture.
## This should be called at the start of whatever process you're tracking
## (usually at the start of a frame, hence the name).
func start_frame(title := ""):
	if _current_frame != null and _has_frame_changes:
		_frame_history.push(_current_frame)
	
	_current_frame = FrameLog.new(id, title)
	_has_frame_changes = title != ""


## Adds to the title/header information for the current frame.
## Multiple calls will build up the title string without newlines.
## This is useful for high-level state information like "AI: Thinking | Moving to: (10, 20)".
func append_frame_title(title: String):
	if _current_frame == null:
		_current_frame = FrameLog.new(id)
	_current_frame.title += title
	_has_frame_changes = true


## Logs a line to the current frame's detailed data.
## Each line will be appended with a newline character.
func in_frame(line: String):
	if _current_frame == null:
		_current_frame = FrameLog.new(id)
	_current_frame.details += line + "\n"
	_has_frame_changes = true


## Marks the frame data as complete. This indicates that all expected data
## has been captured and the frame string is ready for access.
func end_frame():
	if _current_frame != null:
		_current_frame.is_complete = true
		_frame_history.push(_current_frame)
		_has_frame_changes = false


## Returns the current frame's title string.
## If the frame is not complete, includes a warning about potentially missing data.
func get_frame_title() -> String:
	if _current_frame == null:
		return ""
	return _current_frame.title


## Returns the current frame's detailed data string.
## If the frame is not complete, includes a warning about potentially missing data.
## If [param prepend_title] is true, the frame title will be included at the start.
func get_frame(prepend_title := false) -> String:
	if _current_frame == null:
		return ""
	return _current_frame.format(prepend_title)


## Prints a message at a specific level. Equivalent to calling [method error], [method info], etc.
func print_at_level(message: String, level):
	match level:
		LogLevel.ERROR:
			error(message)
		LogLevel.WARNING:
			warning(message)
		LogLevel.INFO:
			info(message)
		LogLevel.DEBUG:
			debug(message)
		LogLevel.VERBOSE:
			verbose(message)
		LogLevel.SILENT:
			error("Attempted to print at ''SILENT'' logging level.")
		_:
			error("Attempted to print at an invalid logging level.")


## Prints the entire message history. This is called automatically from [method error] and
## [method throw_assert], but you can dump errors manually if you don't want to add an entry
## to the print logs.
func error_print():
	var divider_color = settings.module_name_color.to_html(false)
	var message = "[b][color=#%s]-=-=- Error Encountered! %s Module History Starts Here -=-=-[/color][/b]" % [
		divider_color,
		id
	]
	
	# Add all logged messages in chronological order
	for entry in _log_history.get_all():
		message += "\n" + entry.format(settings)
	
	# Add frame history
	var frames = _frame_history.get_all()
	if frames.size() > 0:
		message += "\n[b][color=#%s]-=-=- Frame History: -=-=-[/color][/b]" % divider_color
		for frame in frames:
			message += "\n" + frame.format(true)
	
	# Add current frame if it exists and has changes
	if _current_frame != null and _has_frame_changes:
		if _current_frame.is_complete:
			message += "\n[b][color=#%s]-=-=- Current Frame: -=-=-[/color][/b]\n" % divider_color
		else:
			message += "\n[b][color=#%s]-=-=- Current Frame (INCOMPLETE): -=-=-[/color][/b]\n" % divider_color
		message += _current_frame.format(true)
	
	message += "\n[b][color=#%s]-=-=- Error Encountered! %s Module History Ends Here -=-=-[/color][/b]" % [
		divider_color,
		id
	]
	
	_print_console(message)
	print_rich(message)


## Dumps error information to file. If we are in the editor, opens the LogViewer panel as well.
func error_dump() -> Error:
	var logger_data = {
		self.id: self.to_dict()
	}
	
	return ErrorDump.save_dump(logger_data, ErrorDump.DumpReason.ERROR)


## Returns just the essential log data as a dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"log_history": _log_history.to_dict(),
		"frame_history": _frame_history.to_dict(),
		"current_frame": _current_frame.to_dict() if _current_frame and _has_frame_changes else null
	}


# Helper function to create and store a log entry
func _log(level: LogLevel, message: String) -> LogEntry:
	var entry = LogEntry.new(level, id, message)
	if archive_level >= level:
		_log_history.push(entry)
	return entry


func _exit_tree():
	Print._unregister_logger(self)


func _print_console(message: String):
	if _console:
		_console.Text.append_text(message + "\n")
