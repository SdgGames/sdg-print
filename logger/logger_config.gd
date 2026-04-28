@tool
class_name LoggerConfig extends Resource
## Resource class that stores configuration for a specific logger.
##
## Logger_Config provides a way to define loggers through the editor.
## Each instance specifies a logger name and its print/archive verbosity levels.
## These configurations can be added to the Project Settings under debug/logging/loggers
## to automatically initialize loggers at startup.

## The name of the logger. Must be unique across all loggers.
@export var name := "Log"

## The print (console) level for the logger.
## Controls what messages appear in the Output panel during execution.
@export_enum("Silent", "Error", "Warning", "Info", "Debug", "Verbose")
var print_level: int = 5

## The archive (file write) level for the logger.
## Controls what messages are saved for error dumps and debugging.
@export_enum("Silent", "Error", "Warning", "Info", "Debug", "Verbose")
var archive_level: int = 5


## Create a new LoggerConfig with default values.
func _init(_name := "Log", _print := 5, _archive := 5) -> void:
	name = _name
	print_level = _print
	archive_level = _archive
