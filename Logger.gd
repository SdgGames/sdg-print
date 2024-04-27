@icon("res://addons/sdg-print/Logger.svg")
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
func error_dump():
	var message = "[b][color=magenta]-=-=- Error Encountered! %s Module History Starts Here -=-=-[/color][/b]" % [id] + \
			_message_history + "\n[b][color=magenta]-=-=- Error Encountered! %s Module History Ends Here   -=-=-[/color][/b]" % [id]
	_print_console(message)
	print_rich(message)


# Unregister before deletion.
func _exit_tree():
	Print._unregister_logger(self)


# Print to the in-game console (if it exists).
func _print_console(message: String):
	if _console:
		_console.Text.append_text(message + "\n")
