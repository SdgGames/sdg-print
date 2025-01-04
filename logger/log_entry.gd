class_name LogEntry extends RefCounted
## Stores a single log entry with all associated metadata.
##
## LogEntry maintains the data for a single print statement in the logging system.
## Instead of storing prints as formatted strings, this class keeps all components
## separate to allow for filtering and formatted output after the fact.

## The timestamp when this log entry was created (as Unix timestamp)
var timestamp: float

## The logging level for this entry. See [enum Logger.LogLevel]
var level: Logger.LogLevel

## The module/logger name that created this entry
var module: StringName

## The actual message content
var message: String

## The engine frame number when this entry was created
var frame_number: int

## A copy of the current frame.
var current_frame: FrameLog = null


## Creates a new LogEntry that wraps frame data
static func wrap_frame(frame: FrameLog, module: StringName) -> LogEntry:
	var entry = LogEntry.new(
		Logger.LogLevel.FRAME_DATA_ONLY,
		module,
		"", # Minimize file size, we can generate a message when building from a dictionary later.
		frame
	)
	return entry


func _init(level: Logger.LogLevel, module: StringName, message: String, current_frame: FrameLog):
	self.timestamp = Time.get_unix_time_from_system()
	self.level = level
	self.module = module
	self.message = message
	self.frame_number = Engine.get_frames_drawn()
	self.current_frame = current_frame


## Returns the entry formatted according to the provided settings.
## This maintains compatibility with the existing print system's formatting.
func format(settings: PrintSettings) -> String:
	var formatted_message := ""
	var module_width = settings.max_module_width
	if !Engine.is_editor_hint():
		module_width = Print._current_module_width
	
	# Add timestamp if enabled
	if settings.show_timestamps:
		var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
		var time_string = "%02d:%02d:%02d" % [
			datetime.hour,
			datetime.minute, 
			datetime.second
		]
		formatted_message += "[color=#%s][%s][/color] " % [
			settings.timestamp_color.to_html(false),
			time_string
		]
	
	# Add module name if enabled
	if settings.show_module_names:
		formatted_message += "[b][color=#%s]%-*s[/color][/b] " % [
			settings.module_name_color.to_html(false),
			module_width,
			module
		]
	
	# Add log level if enabled
	if settings.show_log_levels:
		var level_name = Logger.LogLevel.keys()[level]
		formatted_message += "[color=#%s]%-*s[/color] " % [
			settings.get_level_color(level).to_html(false),
			8,
			level_name + ":"
		]
	
	# Add the actual message
	formatted_message += message
	
	return formatted_message


## Returns just the timestamp formatted as a time string (HH:MM:SS)
func get_time_string() -> String:
	var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d:%02d:%02d" % [
		datetime.hour,
		datetime.minute, 
		datetime.second
	]


## Returns the full datetime as a dictionary with keys:
## year, month, day, weekday, hour, minute, second
func get_datetime() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(timestamp)


## Returns a dictionary representation of the log entry
func to_dict() -> Dictionary:
	return {
		"timestamp": timestamp,
		"level": Logger.LogLevel.keys()[level],
		"message": message,
		"frame_number": frame_number,
		"current_frame": null if current_frame == null else current_frame.to_dict()
	}


## Creates a LogEntry from a dictionary
static func from_dict(data: Dictionary, module: StringName) -> LogEntry:
	var level_idx = Logger.LogLevel.keys().find(data.level)
	var entry = LogEntry.new(level_idx, module, data.message, null)
	entry.timestamp = data.timestamp
	entry.frame_number = data.frame_number
	if data.current_frame != null:
		entry.current_frame = FrameLog.from_dict(data.current_frame)
		# We don't store a message to save space. If we are loading this from a file,
		# let's use the space to generate a meaningful message.
		if entry.level == Logger.LogLevel.FRAME_DATA_ONLY:
			entry.message = "Frame %s %s" % [entry.frame_number, entry.current_frame.title]
	return entry
