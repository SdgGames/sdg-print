extends Node

var logs = {}
@export var warning_count := 0
@export var error_count := 0


enum {
	SILENT = 0,
	ERROR = 1,
	WARNING = 2,
	INFO = 3,
	DEBUG = 4,
	VERBOSE = 5
}


func _ready():
	for module_id in PrintScope.modules.keys():
		var config = PrintScope.modules[module_id]
		var log: Log
		if $"/root/Console":
			log = Log.new(config["name"], module_id, config["level"], $"/root/Console")
		else:
			log = Log.new(config["name"], module_id, config["level"])
		if config.has("archive"):
			log.archive_level = config["archive"]
		logs[config["name"]] = log
		logs[module_id] = log


func add_log(log):
	if log.name in logs or log.id in logs:
		print_debug("Log with this name or ID already exists.")
		return
	logs[log.name] = log
	logs[log.id] = log


## Returns the logger instance for the selected module.
func get_logger(identifier) -> Log:
	if identifier in logs:
		return logs[identifier]
	else:
		print_debug("No log with this name or ID.")
		return null


## Prints to the selected logger instance at the specified level.
## If no level is indicated, prints at DEBUG level.
func from(identifier, message: String, level = Log.LogLevel.DEBUG):
	get_logger(identifier).print_at_level(message, level)


## Turns off all loggers. Loggers will still increment the warning_count and error_count in the Print singleton.
func silence_all():
	for id in PrintScope.modules.keys():
		logs[id].print_level = Log.LogLevel.SILENT
		logs[id].archive_level = Log.LogLevel.SILENT


# Like silence_all, but sets to ERROR 
func silence_non_error_printing():
	for id in PrintScope.modules.keys():
		logs[id].print_level = Log.LogLevel.ERROR


# Clears all previous errors and warnings for every logger in the array.
func start_all():
	for id in PrintScope.modules.keys():
		logs[id].start()


func clear_warnings():
	warning_count = 0


func clear_errors():
	error_count = 0
