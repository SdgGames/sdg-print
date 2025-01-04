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
	
	## Get all entries, optionally filtered by level, sorted by timestamp (newest first)
	func get_entries(min_level := Logger.LogLevel.VERBOSE, append_frames := false) -> Array[LogEntry]:
		var entries: Array[LogEntry] = []
		
		# Add log entries that meet the minimum level
		for entry in log_history.get_all():
			if entry.level <= min_level:
				entries.append(entry)
		
		# Add frame entries
		for entry in frame_history.get_all():
			entries.append(entry)
		
		# Sort by timestamp, newest first
		entries.sort_custom(
			func(a: LogEntry, b: LogEntry) -> bool:
				return a.timestamp > b.timestamp
		)
		
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
## If collated is false, entries are grouped by module
func get_all_entries(collated := true) -> Array[LogEntry]:
	if collated:
		return _get_collated_entries()
	else:
		return _get_module_grouped_entries()


## Get all entries sorted only by timestamp (newest first)
func _get_collated_entries() -> Array[LogEntry]:
	var all_entries: Array[LogEntry] = []
	
	# Collect all entries from all loggers
	for logger in loggers.values():
		all_entries.append_array(logger.get_entries())
	
	# Sort by timestamp, newest first
	all_entries.sort_custom(
		func(a: LogEntry, b: LogEntry) -> bool:
			return a.timestamp > b.timestamp
	)
	
	return all_entries


## Get all entries grouped by module, then sorted by timestamp (newest first)
func _get_module_grouped_entries() -> Array[LogEntry]:
	var all_entries: Array[LogEntry] = []
	
	# Get a sorted list of module IDs for consistent ordering
	var module_ids = loggers.keys()
	module_ids.sort()
	
	# Add entries module by module
	for module_id in module_ids:
		var logger = loggers[module_id]
		all_entries.append_array(logger.get_entries())
	
	return all_entries
