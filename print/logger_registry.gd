@tool
class_name LoggerRegistry extends Resource
## Resource that manages a collection of logger configurations for the Print system.
## 
## Each project can create its own registry resource and reference it in
## Project Settings under debug/logging/logger_registry_path.
## The Print singleton will automatically load this registry and create all defined loggers
## when the game starts.

## Project Settings path for the logger registry
const REGISTRY_PATH_SETTING = PrintSettings.SETTINGS_PATH + "logger_registry_path"
## Project Settings path for requiring registry
const REQUIRE_REGISTRY_SETTING = PrintSettings.SETTINGS_PATH + "require_registry"

## Configuration for the Print logger (required)
@export var print_logger: LoggerConfig:
	get:
		if print_logger == null:
			print_logger = LoggerConfig.new("Print", Log.LogLevel.INFO, Log.LogLevel.VERBOSE)
			notify_property_list_changed()
		return print_logger
	set(value):
		if value == null:
			print_logger = LoggerConfig.new("Print", Log.LogLevel.INFO, Log.LogLevel.VERBOSE)
		else:
			print_logger = value

## Configuration for the Global logger (required)
@export var global_logger: LoggerConfig:
	get:
		if global_logger == null:
			global_logger = LoggerConfig.new("Global", Log.LogLevel.VERBOSE, Log.LogLevel.VERBOSE)
			notify_property_list_changed()
		return global_logger
	set(value):
		if value == null:
			global_logger = LoggerConfig.new("Global", Log.LogLevel.VERBOSE, Log.LogLevel.VERBOSE)
		else:
			global_logger = value

## Array of additional logger configurations
@export var loggers: Array[LoggerConfig] = []


## When adding loggers to a new registry, apply sensible default values
func _init(create_game_logger := true) -> void:
	if create_game_logger:
		loggers.append(LoggerConfig.new("Game", Log.LogLevel.VERBOSE, Log.LogLevel.VERBOSE))


## Register the logger registry path setting in Project Settings.
## This is called by PrintSettings._register_settings().
static func register_project_settings() -> void:
	# Register registry path setting
	if not ProjectSettings.has_setting(REGISTRY_PATH_SETTING):
		ProjectSettings.set_setting(REGISTRY_PATH_SETTING, "")
		ProjectSettings.set_initial_value(REGISTRY_PATH_SETTING, "")
		
		ProjectSettings.add_property_info({
			"name": REGISTRY_PATH_SETTING,
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.tres"
		})
	
	# Register require_registry setting
	if not ProjectSettings.has_setting(REQUIRE_REGISTRY_SETTING):
		ProjectSettings.set_setting(REQUIRE_REGISTRY_SETTING, true)
		ProjectSettings.set_initial_value(REQUIRE_REGISTRY_SETTING, true)
		
		ProjectSettings.add_property_info({
			"name": REQUIRE_REGISTRY_SETTING,
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": ""
		})


## Load the logger registry from Project Settings.
## If the registry cannot be found or loaded, an error is logged
## and a default registry is returned.
static func load_from_project_settings() -> LoggerRegistry:
	# Get the registry path from project settings
	var registry_path = ProjectSettings.get_setting(REGISTRY_PATH_SETTING, "")
	
	# Check if a path is set. You need to create a reosurce to manage autoload loggers.
	if registry_path.is_empty():
		if ProjectSettings.get_setting(REQUIRE_REGISTRY_SETTING, true):
			assert(false, "Please create a LoggerRegistry resource and add it to %s%s%s%s instead." %
					[REGISTRY_PATH_SETTING,
					" in the Project Settings. If you don't ",
					"want to create global loggers this way, disable ",
					REQUIRE_REGISTRY_SETTING])
		return LoggerRegistry.new(false)
	
	# Try to load the registry resource
	if ResourceLoader.exists(registry_path):
		var resource = ResourceLoader.load(registry_path)
		if resource is LoggerRegistry:
			return resource
		else:
			assert(false, "Resource at " + registry_path + " is not a LoggerRegistry")
			return LoggerRegistry.new()
	else:
		assert(false, "Log registry not found at path: " + registry_path)
		return LoggerRegistry.new()
