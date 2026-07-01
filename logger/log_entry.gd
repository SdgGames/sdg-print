class_name LogEntry extends RefCounted
## Stores a single log entry with all associated metadata.
##
## LogEntry maintains the data for a single print statement in the logging system.
## Instead of storing prints as formatted strings, this class keeps all components
## separate to allow for filtering and formatted output after the fact.

## The timestamp in microseconds when this log entry was created
var timestamp: int  # Changed from float to int for microseconds

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
		Logger.LogLevel.FRAME_ONLY,
		module,
		"", # Minimize file size, we can generate a message when building from a dictionary later.
		frame
	)
	return entry


func _init(level: Logger.LogLevel, module: StringName, message: String, current_frame: FrameLog):
	self.timestamp = Time.get_ticks_usec()  # Use microsecond timestamp
	self.level = level
	self.module = module
	self.message = message
	self.frame_number = Engine.get_frames_drawn()
	self.current_frame = current_frame


## Returns the entry formatted according to the provided settings.
func format(settings: PrintSettings) -> String:
	var formatted_message := ""
	var module_width = settings.max_module_width
	if !Engine.is_editor_hint():
		module_width = Print._current_module_width
	
	# Add timestamp if enabled
	if settings.show_timestamps:
		# Convert microseconds to a readable time format using Time singleton
		var msec = timestamp / 1000  # Convert to milliseconds for display
		var seconds = msec / 1000
		var minutes = seconds / 60
		var hours = minutes / 60
		
		var time_string = "%02d:%02d:%02d.%03d" % [
			hours % 24,
			minutes % 60,
			seconds % 60,
			msec % 1000
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


## Returns just the timestamp formatted as a time string (HH:MM:SS.mmm)
func get_time_string() -> String:
	var msec = timestamp / 1000  # Convert to milliseconds for display
	var seconds = msec / 1000
	var minutes = seconds / 60
	var hours = minutes / 60
	
	return "%02d:%02d:%02d.%03d" % [
		hours % 24,
		minutes % 60,
		seconds % 60,
		msec % 1000
	]


## Returns a dictionary representation of the log entry
func to_dict() -> Dictionary:
	return {
		"timestamp": timestamp,  # Store raw microseconds
		"level": Logger.LogLevel.keys()[level],
		"message": message,
		"frame_number": frame_number,
		"current_frame": null if current_frame == null else current_frame.to_dict()
	}


## Creates a LogEntry from a dictionary
static func from_dict(data: Dictionary, module: StringName) -> LogEntry:
	var level_idx = Logger.LogLevel.keys().find(data.level)
	var entry = LogEntry.new(level_idx, module, data.message, null)
	entry.timestamp = data.timestamp  # Load raw microseconds
	entry.frame_number = data.frame_number
	if data.current_frame != null:
		entry.current_frame = FrameLog.from_dict(data.current_frame)
	return entry
