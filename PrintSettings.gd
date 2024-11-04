@icon("res://addons/sdg-print/PrintSettings_icon.svg")
class_name PrintSettings extends Resource
## Resource class that stores formatting and color settings for loggers.
##
## PrintSettings provides a centralized way to configure how loggers format and color their output.
## Settings can be configured globally through ProjectSettings, created in the editor, or generated
## at runtime. Each logger can use the global settings from the Print singleton or have its own
## PrintSettings instance for custom formatting.
## [br][br]
## Example usage in code:
## [codeblock]
## var settings = PrintSettings.new()
## settings.show_timestamps = false
## settings.error_color = Color.DARK_RED
## 
## # Create logger with custom settings
## var logger = Print.create_logger("CustomLogger", Print.VERBOSE, Print.VERBOSE, settings)
## [/codeblock]
##
## Example usage in editor:
## [codeblock]
## @export var my_logger_settings: PrintSettings
## [/codeblock]

## Whether to show timestamps in log messages.
@export var show_timestamps := true

## Whether to show module names/logger IDs in log messages.
@export var show_module_names := true

## Whether to show log levels (ERROR, WARNING, etc.) in log messages.
@export var show_log_levels := true

## Maximum width allowed for module names in the output.
@export_range(1, 100, 1, "or_greater") var max_module_width := 20

@export_group("Log Level Colors")
## Color used for error-level log messages.
@export var error_color := Color.INDIAN_RED

## Color used for warning-level log messages.
@export var warning_color := Color.ORANGE

## Color used for info-level log messages.
@export var info_color := Color.CYAN

## Color used for debug-level log messages.
@export var debug_color := Color.LIME_GREEN

## Color used for verbose-level log messages.
@export var verbose_color := Color.MEDIUM_PURPLE

@export_group("Component Colors")
## Color used for the timestamp component in log messages.
@export var timestamp_color := Color.CORNFLOWER_BLUE

## Color used for the module name component in log messages.
@export var module_name_color := Color.MAGENTA

# ProjectSettings paths and default values
const SETTINGS_PATH = "game/logging/"
const DEFAULT_SETTINGS = {
	"format/show_timestamps": {
		"type": TYPE_BOOL,
		"value": true
	},
	"format/show_module_names": {
		"type": TYPE_BOOL,
		"value": true
	},
	"format/show_log_levels": {
		"type": TYPE_BOOL,
		"value": true
	},
	"format/max_module_width": {
		"type": TYPE_INT,
		"value": 20,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1,100,1"
	},
	"colors/error": {
		"type": TYPE_COLOR,
		"value": Color.INDIAN_RED
	},
	"colors/warning": {
		"type": TYPE_COLOR,
		"value": Color.ORANGE
	},
	"colors/info": {
		"type": TYPE_COLOR,
		"value": Color.CYAN
	},
	"colors/debug": {
		"type": TYPE_COLOR,
		"value": Color.LIME_GREEN
	},
	"colors/verbose": {
		"type": TYPE_COLOR,
		"value": Color.MEDIUM_PURPLE
	},
	"colors/timestamp": {
		"type": TYPE_COLOR,
		"value": Color.CORNFLOWER_BLUE
	},
	"colors/module_name": {
		"type": TYPE_COLOR,
		"value": Color.MAGENTA
	}
}


## Registers all logging-related settings in ProjectSettings if they don't exist.
## Called automatically by the Print singleton during initialization.
static func _register_settings() -> void:
	for setting_name in DEFAULT_SETTINGS:
		var full_path = SETTINGS_PATH + setting_name
		var setting_info = DEFAULT_SETTINGS[setting_name]
		
		if not ProjectSettings.has_setting(full_path):
			ProjectSettings.set_setting(full_path, setting_info["value"])
			ProjectSettings.set_initial_value(full_path, setting_info["value"])
			
			var info = {
				"name": full_path,
				"type": setting_info["type"],
			}
			if setting_info.has("hint"):
				info["hint"] = setting_info["hint"]
			if setting_info.has("hint_string"):
				info["hint_string"] = setting_info["hint_string"]
				
			ProjectSettings.add_property_info(info)


## Creates a new PrintSettings instance with values from ProjectSettings.
## [br][br]
## This is the recommended way to create a new PrintSettings instance when you
## want to start with the global defaults.
static func from_project_settings() -> PrintSettings:
	var settings = PrintSettings.new()
	settings.load_from_project_settings()
	return settings


## Updates this PrintSettings instance with values from ProjectSettings.
func load_from_project_settings() -> void:
	show_timestamps = ProjectSettings.get_setting(SETTINGS_PATH + "format/show_timestamps")
	show_module_names = ProjectSettings.get_setting(SETTINGS_PATH + "format/show_module_names")
	show_log_levels = ProjectSettings.get_setting(SETTINGS_PATH + "format/show_log_levels")
	max_module_width = ProjectSettings.get_setting(SETTINGS_PATH + "format/max_module_width")
	
	error_color = ProjectSettings.get_setting(SETTINGS_PATH + "colors/error")
	warning_color = ProjectSettings.get_setting(SETTINGS_PATH + "colors/warning")
	info_color = ProjectSettings.get_setting(SETTINGS_PATH + "colors/info")
	debug_color = ProjectSettings.get_setting(SETTINGS_PATH + "colors/debug")
	verbose_color = ProjectSettings.get_setting(SETTINGS_PATH + "colors/verbose")
	timestamp_color = ProjectSettings.get_setting(SETTINGS_PATH + "colors/timestamp")
	module_name_color = ProjectSettings.get_setting(SETTINGS_PATH + "colors/module_name")


## Gets the appropriate color for a specific log level.
## [br][br]
## If an invalid level is provided, returns Color.WHITE as a fallback.
func get_level_color(level: Logger.LogLevel) -> Color:
	match level:
		Logger.LogLevel.ERROR:
			return error_color
		Logger.LogLevel.WARNING:
			return warning_color
		Logger.LogLevel.INFO:
			return info_color
		Logger.LogLevel.DEBUG:
			return debug_color
		Logger.LogLevel.VERBOSE:
			return verbose_color
		_:
			return Color.WHITE  # Default fallback


## Creates a new PrintSettings instance with optional property overrides.
## [br][br]
## [param overrides] is a dictionary of property names and their new values.
## Only existing properties will be overridden.
func duplicate_with_overrides(overrides := {}) -> PrintSettings:
	var new_settings = duplicate()
	for key in overrides:
		if new_settings.get(key) != null:  # Only set if property exists
			new_settings.set(key, overrides[key])
	return new_settings
