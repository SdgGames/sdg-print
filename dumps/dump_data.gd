class_name DumpData extends RefCounted
## Manages the data for a single error dump, providing filtering and sorting capabilities.

## Represents a single logger's data within an error dump.
class LoggerData extends RefCounted:
	var id: StringName
	var log_history: RingBuffer
	var frame_history: RingBuffer
	
	func _init(logger_id: StringName):
		id = logger_id
		
	## Load logger data from a dictionary
	func load_from_dict(data: Dictionary) -> void:
		# Load log history
		log_history = RingBuffer.from_dict(data.log_history, LogEntry.from_dict.bind(id))
		# Load frame history
		frame_history = RingBuffer.from_dict(data.frame_history, LogEntry.from_dict.bind(id))
	
	## Get all entries, optionally filtered by level
	func get_entries(min_level := Logger.LogLevel.VERBOSE, append_frames := false) -> Array[LogEntry]:
		var entries: Array[LogEntry] = []
		
		# Add log entries that meet the minimum level
		for entry in log_history.get_all():
			if entry.level <= min_level:
				entries.append(entry)
		
		# Add frame entries that meet the minimum level
		for entry in frame_history.get_all():
				entries.append(entry)
		
		return entries


## Information about when and why this dump was created
var metadata: Dictionary
## Collection of logger data, keyed by logger ID
var loggers: Dictionary = {}


## Load dump data from a dictionary
func load_from_dict(data: Dictionary) -> bool:
	metadata = {
		"timestamp": data.timestamp,
		"reason": data.reason,
		"module_width": data.module_width
	}
	
	# Load each logger's data
	for logger_id in data.loggers:
		var logger_data = LoggerData.new(logger_id)
		logger_data.load_from_dict(data.loggers[logger_id])
		loggers[logger_id] = logger_data
	
	return true


## Get all entries from all loggers in chronological order
func get_all_entries() -> Array[LogEntry]:
	var all_entries: Array[LogEntry] = []
	
	# Collect all entries from all loggers
	for logger in loggers.values():
		# Add regular log entries
		all_entries.append_array(logger.log_history.get_all())
		
		# Add frame entries
		all_entries.append_array(logger.frame_history.get_all())
	
	# Sort by timestamp
	all_entries.sort_custom(
		func(a: LogEntry, b: LogEntry) -> bool:
			return a.timestamp < b.timestamp
	)
	
	return all_entries
