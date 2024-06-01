@icon("res://addons/sdg-print/Print_icon.svg")
class_name SDG_Print extends Node
## Print singleton. Auto-registers under the name "Print"
##
## The Print module creates and maintains [Logger] instances.
## You can use this as a more advanced [code]print[/code] function through the [method info], 
## [method debug], etc. methods, or use it to automatically manage multiple [Logger]s for each
## major component of the project.
## [br][br]
## The primary goal of this submodule is to allow print statements to remain in place when they are
## needed, but to also stop unnecessary prints from clogging the Output window.
## [br]Both goals are met by giving each game component its own [Logger] instance with verbosity
## filters. While developing a part of the game, you can turn up the verbosity to see what is
## happening in detail. When you move on to the next component, just turn the verbosity back down.
## When an error is encountered, you will have the option to dump all of the prints that were being
## filtered, so you can get the information you need, when you need it.
## [br][br]
## The Print Global sets up two [Logger]s automatically.
## [br]1. The [code]"Print"[/code] [Logger] is used internally,
## and should be left alone. (If you are registering and un-registering a lot of [Logger]s, you may
## want to turn the verbosity down.)
## [br]2. All generic print calls are passed through to the [code]"Global"[/code] [Logger].
## You can use this [Logger] if you don't want to set up something more specific, or if the printing
## frequency is low overall.
## [br][br]
## [Logger] instances will automatically register with the Print singleton once they are created. If
## you want to create a global logger for a component, use [method create_logger]. If you want a
## per-instance logger, create a [Logger] node, and it will be tracked automatically.
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
## This module is also integrated with the [Console](https://github.com/SdgGames/godot-console)
## by default. If the Console singleton does not exist, Print will automatically disable the
## integration functionality.
## [br][br]
## You can find the source code for this project here: [url]https://github.com/SdgGames/sdg-print[/url]
## [br]This is designed to work as a Git submodule, so you can just add the Git project under
## [code]addons/sdg-print[/code], and maintain it through Git instead of through Godot.

enum {
	SILENT = 0,
	ERROR = 1,
	WARNING = 2,
	INFO = 3,
	DEBUG = 4,
	## [br]Mirrors the values of [enum Logger.LogLevel]. Functions like [method Print.from] can take 
	## this as an argument instead of taking [enum Logger.LogLevel]. For example, 
	## [code]Print.from("Player_Submodule_Logger", "Hello World!", Print.INFO)[/code]
	VERBOSE = 5
}

## The default [enum Logger.LogLevel] for printing from the "Print" logger.
const self_print_level := Logger.LogLevel.VERBOSE
## The default [enum Logger.LogLevel] for archiving from the "Print" logger.
const self_archive_level := Logger.LogLevel.VERBOSE

## The number of warnings encountered since the game started.
@export var warning_count := 0
## The number of errors encountered since the game started.
@export var error_count := 0

# Contains all of the active [Logger]s in the project.
var _logs := {}
# References to the global and local logger instances.
var _global_logger: Logger
var _print_logger: Logger


func _init():
	_print_logger = Logger.new()._second_init("Print", self_print_level, self_archive_level, Logger.LogType.SINGLETON)
	add_child(_print_logger)
	_global_logger = create_logger("Global", VERBOSE, VERBOSE)


# Connect to the Console (if it is present)
func _ready():
	if !has_node("/root/Console"):
		return
	var console = get_node("/root/Console")
	_global_logger._console = console
	console.add_command("silence_all_prints", self, "silence_all")\
			.set_description("Disables all printing to this console and the Output window or external console")\
			.register()
	console.add_command("silence_non_error_prints", self, "silence_non_error_printing")\
			.set_description("Disables all non-error printing.")\
			.register()
	console.add_command("dump_logger", self, "_dump_logger")\
			.add_argument("identifier", TYPE_STRING)\
			.set_description("Dumps all of the print statements for the specified logger.")\
			.register()
	console.add_command("dump_all_loggers", self, "dump_loggers")\
			.set_description("Dumps all of the prints stored in all of the loggers. This can be a LOT of text.")\
			.register()
	console.add_command("list_loggers", self, "list_loggers")\
			.set_description("Prints the names of all of the loggers to the console.")\
			.register()


## Creates and returns the [Logger] instance for the module that matches [param identifier].
## Will always overwrite the logger's [member Logger.print_level] and [member Logger.archive_level]
## with the provided values. If you need to reference the [Logger] before it is created
## (such as during [code]_ready[/code] calls in scene creation), you can safely call
## [code]get_logger(id, true)[/code] to generate the [Logger] object. The object will default to
## [code](VERBOSE, VERBOSE)[/code] until [method create_logger] is finally called.
func create_logger(identifier, print_level, archive_level) -> Logger:
	var id = _get_id(identifier)
	if id in _logs:
		_print_logger.debug("Print.create_logger found existing logger %s." % id)
		var logger: Logger = _logs[id]
		logger.print_level = print_level
		logger.archive_level = archive_level
		return logger
	else:
		_print_logger.debug("Print.create_logger creating new logger %s." % id)
		var logger = Logger.new()._second_init(id, Logger.LogLevel.values()[print_level], \
				Logger.LogLevel.values()[archive_level], _get_type(identifier))
		add_child(logger)
		_logs[id] = logger
		return logger


## Returns the [Logger] instance for the selected module.
## Will throw an error and return [code]null[/code] if no [Logger] can be found matching
## [param identifier]. Set [param get_or_create] to [code]true[/code] to bypass the error.
## This is useful for referencing a [Logger] that you instance elsewhere in the scene.
## See [method create_logger] for additional details about [Logger] creation.
func get_logger(identifier, get_or_create := false) -> Logger:
	var id = _get_id(identifier)
	if id in _logs:
		_print_logger.verbose("get_logger found existing logger %s." % id)
		return _logs[id]
	elif get_or_create:
		return create_logger(identifier, VERBOSE, VERBOSE)
	else:
		_print_logger.throw_assert("No logger exists with name %s." % id, false)
		return null


## Prints to the selected [Logger] instance at the specified [param level].
## If no level is indicated, prints at DEBUG level.
## Will throw an error if no [Logger] matches [param identifier]
func from(identifier, message: String, level = Logger.LogLevel.DEBUG):
	var logger_id = _get_id(identifier)
	if _logs.has(logger_id):
		_logs[logger_id].print_at_level(message, level)
	else:
		_print_logger.throw_assert("No log with this identifier: %s" % logger_id, false)


## Pass-through to the Global print singleton.
## Logs and error and throws an assert with the given message.
## Asserts pause code execution.
## By default, this will dump the entire message history to the console.
## If you just want to print the current error, set [param dump_error] to [code]false[/code].
func throw_assert(message: String, dump_error := true):
	_global_logger.throw_assert(message, dump_error)


## Calls [method Logger.error_dump] on each of the [Logger]s in the project.
func dump_all():
	for id in _logs.keys():
		_logs[id].error_dump()


## Pass-through to the Global print singleton.
## Prints an error to screen and pushes to console.
## By default, this will dump the entire message history to the console.
## If you just want to print the current error, set [param dump_error] to [code]false[/code].
func error(message: String, dump_error := true):
	_global_logger.error(message, dump_error)


## Pass-through to the Global print singleton.
## Prints a WARNING to screen and pushes to console.
func warning(message: String):
	_global_logger.warning(message)


## Pass-through to the Global print singleton.
## Prints an INFO message to screen and console.
func info(message: String):
	_global_logger.info(message)


## Pass-through to the Global print singleton.
## Prints a DEBUG message to screen and console.
func debug(message: String):
	_global_logger.debug(message)


## Pass-through to the Global print singleton.
## Prints a VERBOSE message to screen and console. This uses [code]print_verbose[/code], 
## so it will only display if [code](OS.is_stdout_verbose() == true)[/code]
func verbose(message: String):
	_global_logger.verbose(message)


## Turns off all [Logger]s. [Logger]s will still increment the [member warning_count] and
## [member error_count] in the Print singleton.
func silence_all():
	for id in _logs.keys():
		_logs[id].print_level = Logger.LogLevel.SILENT
		_logs[id].archive_level = Logger.LogLevel.SILENT


## Sets all [Loggers] to only print errors.
func silence_non_error_printing():
	for id in _logs.keys():
		_logs[id].print_level = Logger.LogLevel.ERROR


## Resets warning and error counts to zero.
## Mainly used by unit test suites to reset for the next test.
func start_all():
	for id in _logs.keys():
		_logs[id].start()
	_print_logger.info("All loggers reset.")


## Prints a list of all registered loggers to the Global print using [method info]. Also returns
## the list as an Array.
func list_loggers() -> Array:
	info(str(_logs.keys()))
	return _logs.keys()


## Calls [Logger.error_dump] on EVERY logger in the project. Be careful, this is a LOT of text.
func dump_loggers():
	for id in _logs.keys():
		_logs[id].error_dump()


# Function for the Console to grab onto. Users can just get the logger first.
func _dump_logger(identifier):
	var logger_id = _get_id(identifier)
	if _logs.has(logger_id):
		_logs[logger_id].error_dump()
	else:
		_print_logger.throw_assert("No log with this identifier: %s" % logger_id, false)


# Adds a new [Logger] to the logging system. Used by the [Logger] class, use [method create_logger] instead.
# I set these to private because they are internal to the module, even if they are called from outside the class.
func _register_logger(logger: Logger):
	if logger.id in _logs:
		if _logs[logger.id] != logger:
			_print_logger.error("A logger with the identifier '%s' is already registered." % logger.id)
		# Else, we already added this logger in the create_logger call.
		return
	_logs[logger.id] = logger
	_print_logger.info("Registered %s logger of type %s." % [logger.id, Logger.LogType.find_key(logger._log_type).to_camel_case()])
	if has_node("/root/Console"):
		logger._console = $"/root/Console"


# Removes a [Logger] from the logging system. Used by the [Logger] class. If you want to delete [Logger]s,
# create them as children of your nodes instead of adding them globally via [member create_logger]
func _unregister_logger(logger: Logger):
	if logger.id in _logs:
		_logs.erase(logger.id)
		_print_logger.info("Un-Registered %s logger of type %s." % [logger.id, Logger.LogType.find_key(logger._log_type).to_camel_case()])
	else:
		_print_logger.error("A logger with the identifier '%s' is not registered." % logger.id)


# Helper function to get a human-readable string reference to the identifier.
# Determines the identifier type and returns it as a string.
# Valid identifier types include:
#    String
#        used as-is
#    Object or Resource
#        Converted to the resource path in the tree.
#    Other/Unknown
#        Any object can be used as a key, but it will convert with str() and may
#        not be easily human-readable as a result.
func _get_id(identifier) -> String:
	var id = ""
	match _get_type(identifier):
		Logger.LogType.SINGLETON:
			id = identifier
		Logger.LogType.OBJECT:
			id = str(identifier.get_path())
		Logger.LogType.UNKNOWN:
			id = str(identifier)
	return id


# Helper function to get the type of a logger.
# Determines the type of the logger based on the identifier.
func _get_type(identifier) -> Logger.LogType:
	var type = Logger.LogType.UNKNOWN
	if identifier is String:
		type = Logger.LogType.SINGLETON
	elif is_instance_valid(identifier):
		type = Logger.LogType.OBJECT
	return type
