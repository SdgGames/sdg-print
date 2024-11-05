class_name FrameLog extends RefCounted
## Stores log information for a single frame of execution.
##
## FrameLog maintains the title and details strings for a single frame of
## execution. This is used by the [Logger] class to track detailed state
## information on a frame-by-frame basis.
## [br][br]
## This class is used internally by the [Logger] class and shouldn't need to be
## created manually.

## The timestamp when this frame data was created (as Unix timestamp)
var timestamp: float

## The module/logger name that created this frame data
var module: String

## The title string for this frame
var title: String

## The detailed information string for this frame
var details: String

## Whether this frame's data collection is complete
var is_complete: bool

## The engine frame number when this data was created
var frame_number: int


func _init(module: String, title := "", details := ""):
	self.timestamp = Time.get_unix_time_from_system()
	self.module = module
	self.title = title
	self.details = details
	self.is_complete = false
	self.frame_number = Engine.get_frames_drawn()


## Returns the timestamp formatted as a time string (HH:MM:SS)
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


## Formats the frame data as a string, optionally including the title.
## If the frame is not complete, includes a warning about potentially missing data.
func format(include_title := false) -> String:
	var output := ""
	
	if not is_complete:
		output = "[WARNING: Frame capture incomplete]\n"
	
	if include_title and title:
		output += "[%s] %s\n" % [get_time_string(), title]
	
	if details:
		output += details
	
	return output


## Returns a dictionary representation of this frame log.
## Useful for serialization or detailed inspection.
func to_dict() -> Dictionary:
	return {
		"timestamp": timestamp,
		"module": module,
		"title": title,
		"details": details,
		"is_complete": is_complete,
		"frame_number": frame_number
	}
