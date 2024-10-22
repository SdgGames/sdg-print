@icon("res://addons/sdg-print/Logger_icon.svg")
class_name Logger extends Node
## More advanced print class that logs events, warnings, and errors for a particular subsystem.
##
## A logging helper for a module or individual object.
## Can print to the standard output ([code]print()[/code]) and to the in-game console (if present).
## The output verbosity can be changed by setting [member print_level] or [member archive_level].
## [br][br]
## If a module's [member print_level] is set to [enum LogLevel.SILENT] nothing will be printed to
## the console, but messages will still be saved to a buffer. If an error is encountered
## (the call might look like: [code]my_logger.error("Something went wrong)[/code]),
## the entire saved buffer will be printed. You can call [method start] to clear the buffer if you
## want to reset the message buffer (starting a new game, loading a new file, etc.).
## [br][br]
## The logger provides a convenient interface for tracking data within a single frame across two 
## levels: a title level for high-level state information, and a detailed level for specifics.
## Use [method start_frame] to clear the previous frame's data. Then, use [method set_frame_title]
## to build up the title string (e.g., "AI: Patrolling | Target: Player") and [method in_frame] to 
## log detailed information line by line. Finally, use [method end_frame] to indicate that the frame
## data is fully written. The title and details can be accessed with [method get_frame_title] and
## [method get_frame] respectively for display in a debugging panel. If accessed before 
## [method end_frame] is called, both getters will prepend a warning to indicate potentially 
## incomplete data.
## [br][br]
## Loggers are managed from the Print singleton (of type [SDG_Print])
## Here is what a generic usage of a [Logger] might look like:
## [codeblock]
## var _log: Logger
## 
## func _ready():
##     _log = Print.create_logger("MyLogger", Print.VERBOSE, Print.VERBOSE)
## 
## func _on_thing_happened():
##     _log.info("A thing just happened.")
##
## func _process(_delta):
##     _log.start_frame()
##     _log.set_frame_title("AI: Patrolling")
##     _log.set_frame_title(" | Target: Player")
##     _log.in_frame("Current waypoint: " + str(current_waypoint))
##     _log.in_frame("Path status: " + path_status)
##     _log.end_frame()
## [/codeblock]


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

# Internal
var _log_type : LogType = LogType.OBJECT
var _console = null
var _message_history := ""
var _frame_complete := false
var _frame_title := ""
var _frame_string := ""
var _last_frame := ""


# Register with the Print singleton when ready.
# If this logger is a child of an existing node, will update the ID accordingly.
func _ready():
	if id == "":
		id = str(get_parent().get_path()).replace("/root/", "")
	Print._register_logger(self)
	start()


# Set up everything that we can't do in an _init call (because Godot calls _init on nodes in the scene tree.
# Returns self so you can chain Logger.new.init(...)
func _second_init(id := "", print_level := LogLevel.VERBOSE, archive_level := LogLevel.VERBOSE, log_type := LogType.OBJECT) -> Logger:
	self.id = id
	self.name = str(id)
	self.print_level = print_level
	self.archive_level = archive_level
	self._log_type = log_type
	return self


## Clears the message history for this logger instance.
## This effectively lets you start a new task. If an error is thrown,
## the entire message history will be printed, starting from this call.
## You can optionally provide a message to print (default level is DEBUG).
func start(message := "", level = LogLevel.DEBUG):
	_message_history = ""
	if message != "":
		print_at_level(message, level)


## Throws an error if the statement is false.
## Also throws an assert so program execution will halt.
func assert_that(is_true, message := ""):
	if !is_true:
		throw_assert(message)


## Logs and error and throws an assert with the given message.
## Asserts guarantee that execution pauses if the following code would crash.
## By default, this will dump the entire message history to the console.
## If you just want to print the current error, set [param dump_error] to [code]false[/code].
## [br]For large errors that might involve multiple modules, set [param dump_all] to true. This will
## dump the message history from all modules. Set [param dump_error] to false to avoid redundancy.
func throw_assert(message: String, dump_error := true, dump_all := false):
		error(message, dump_error, dump_all)
		assert(false)


## Prints an error to screen and pushes to console.
## By default, this will dump the entire message history to the console.
## If you just want to print the current error, set [param dump_error] to [code]false[/code].
## [br]For large errors that might involve multiple modules, set [param dump_all] to true. This will
## dump the message history from all modules. Set [param dump_error] to false to avoid redundancy.
func error(message: String, dump_error := true, dump_all := false):
	# Add to the global error count. (useful for unit testing errors)
	Print.error_count += 1
	var message_formatted = "[color=red]ERROR:   " + message + "[/color]"
	# Store this message in case we need it again!
	if archive_level >= LogLevel.ERROR:
		_message_history += '\n' + message_formatted
	# Print this message to the screen and console.
	if print_level >= LogLevel.ERROR:
		_print_console(message_formatted)
		push_error(message)
		if dump_error:
			error_dump()
		if dump_all:
			Print.dump_all()


## Prints a WARNING to screen and pushes to console.
func warning(message):
	# Add to the global warning count. (useful for unit testing warnings)
	Print.warning_count += 1
	var message_formatted = "[color=orange]WARNING: " + message + "[/color]" 
	# Archive this message if necessary.
	if archive_level >= LogLevel.WARNING:
		_message_history += '\n' + message_formatted
	# Print this message to the screen and console.
	if print_level >= LogLevel.WARNING:
		_print_console(message_formatted)
		push_warning(message)
		# Print the warning to Output as well as pushing to Debugger. This way, it won't get missed!
		if OS.has_feature("editor"):
			print_rich(message_formatted)


## Prints an INFO message to screen and console.
func info(message):
	message = "[color=cyan]INFO:    [/color]" + message
	# Archive this message if necessary.
	if archive_level >= LogLevel.INFO:
		_message_history += '\n' + message
	# Print this message to the screen and console.
	if print_level >= LogLevel.INFO:
		_print_console(message)
		print_rich(message)


## Prints a DEBUG message to screen and console.
func debug(message):
	message = "[color=green]DEBUG:   [/color]" + message
	# Archive this message if necessary.
	if archive_level >= LogLevel.DEBUG:
		_message_history += '\n' + message
	# Print this message to the screen and console.
	if print_level >= LogLevel.DEBUG:
		_print_console(message)
		print_rich(message)


## Prints a VERBOSE message to screen and console. This uses [code]print_verbose[/code], 
## so it will only display if [code](OS.is_stdout_verbose() == true)[/code]
func verbose(message):
	message = "[color=purple]VERBOSE: [/color]" + message
	# Archive this message if necessary.
	if archive_level >= LogLevel.VERBOSE:
		_message_history += '\n' + message
	# Print this message to the screen and console.
	if print_level >= LogLevel.VERBOSE:
		_print_console(message)
		print_rich(message)


## Clears the previous frame's data and prepares for a new frame capture.
## This should be called at the start of whatever process you're tracking
## (usually at the start of a frame, hence the name).
## Setting [param title] has the same effect as calling [method append_frame_title].
func start_frame(title := ""):
	_last_frame = _frame_title + '\n' + _frame_string
	_frame_string = ""
	_frame_title = title
	_frame_complete = false


## Adds to the title/header information for the current frame.
## Multiple calls will build up the title string without newlines.
## This is useful for high-level state information like "AI: Thinking | Moving to: (10, 20)".
func append_frame_title(title: String):
	_frame_title += title


## Logs a line to the current frame's detailed data.
## Each line will be appended with a newline character.
func in_frame(line: String):
	_frame_string += line + "\n"


## Marks the frame data as complete. This indicates that all expected data
## has been captured and the frame string is ready for access.
func end_frame():
	_frame_complete = true


## Returns the current frame's title string.
## If the frame is not complete (end_frame hasn't been called),
## a warning will be prepended to indicate potentially missing data.
func get_frame_title() -> String:
	if not _frame_complete:
		return "[WARNING: Frame capture incomplete] " + _frame_title
	return _frame_title


## Returns the current frame's detailed data string.
## If the frame is not complete (end_frame hasn't been called),
## a warning will be prepended to indicate potentially missing data.
func get_frame() -> String:
	if not _frame_complete:
		return "[WARNING: Frame capture incomplete]\n" + _frame_string
	return _frame_string


## Prints a message at a specific level. Equivalent to calling [method error], [method info], etc.
func print_at_level(message: String, level: LogLevel):
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
## [method assert_that], but you can dump errors manually if you don't want to add an entry
## to the print logs.
## Also appends the frame data for the current frame (if applicable).
func error_dump():
	var message = "[b][color=magenta]-=-=- Error Encountered! %s Module History Starts Here -=-=-[/color][/b]" % [id]
	message += _message_history
	# Add the frame data the the output.
	if _last_frame != "":
		message += "[b][color=magenta]-=-=- Last Frame String: -=-=-[/color][/b]"
		message += _frame_title + '\n' + _frame_string
	if _frame_title != "" or _frame_string != "":
		if _frame_complete:
			message += "[b][color=magenta]-=-=- Current Frame String: -=-=-[/color][/b]"
		else:
			message += "[b][color=magenta]-=-=- Current Frame String (INCOMPLETE): -=-=-[/color][/b]"
		message += _frame_title + '\n' + _frame_string
	message += "\n[b][color=magenta]-=-=- Error Encountered! %s Module History Ends Here   -=-=-[/color][/b]" % [id]
	_print_console(message)
	print_rich(message)


# Unregister before deletion.
func _exit_tree():
	Print._unregister_logger(self)


# Print to the in-game console (if it exists).
func _print_console(message: String):
	if _console:
		_console.Text.append_text(message + "\n")
