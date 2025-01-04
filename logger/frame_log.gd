class_name FrameLog extends RefCounted
## Stores log information for a single frame of execution.
##
## FrameLog maintains the title and details strings for a single frame of
## execution. This is used by the [Logger] class to track detailed state
## information on a frame-by-frame basis.
## [br][br]
## This class is used internally by the [Logger] class and shouldn't be
## created manually.

## The title string for this frame
var title: String

## The detailed information string for this frame
var details: String

## Whether this frame's data collection is complete
var is_complete: bool


func _init(title := "", details := ""):
	self.title = title
	self.details = details
	self.is_complete = false


## Formats the frame data as a string, optionally including the title.
## If the frame is not complete, includes a warning about potentially missing data.
func format(include_title := false) -> String:
	var output := ""
	
	if not is_complete:
		output = "[WARNING: Frame capture incomplete]\n"
	
	if include_title and title:
		output += title + "\n"
	
	if details:
		output += details
	
	return output


## Returns a dictionary representation of this frame log.
## Useful for serialization or detailed inspection.
func to_dict() -> Dictionary:
	return {
		"title": title,
		"details": details,
		"is_complete": is_complete
	}


## Creates a new FrameLog from dictionary data
static func from_dict(data: Dictionary) -> FrameLog:
	var frame = FrameLog.new(data.title, data.details)
	frame.is_complete = data.is_complete
	return frame
