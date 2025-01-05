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
	func get_entries(min_level := Logger.LogLevel.FRAME_ONLY, append_frames := false) -> Array[LogEntry]:
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


## Get all entries with appropriate folding headers
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
	
	return _add_folding_headers(all_entries)


## Get all entries grouped by module with appropriate folding headers
func _get_module_grouped_entries() -> Array[LogEntry]:
	var all_entries: Array[LogEntry] = []
	
	# Get a sorted list of module IDs for consistent ordering
	var module_ids = loggers.keys()
	module_ids.sort()
	
	# Add entries module by module
	for module_id in module_ids:
		var logger = loggers[module_id]
		var module_entries = logger.get_entries()
		if module_entries.size() > 0:
			all_entries.append_array(_add_folding_headers(module_entries))
	
	return all_entries


## Add folding headers based on level transitions
func _add_folding_headers(entries: Array[LogEntry]) -> Array[LogEntry]:
	print("Starting folding process with %d entries" % entries.size())
	var result: Array[LogEntry] = []
	var current_pos := 0
	
	# Process each entry
	while current_pos < entries.size():
		var entry = entries[current_pos]
		print("\nProcessing entry %d: Level %s, Message: %s" % [
			current_pos,
			Logger.LogLevel.keys()[entry.level],
			entry.message.substr(0, 30) + "..."
		])
		
		# Don't process FRAME_ONLY entries
		if entry.level == Logger.LogLevel.FRAME_ONLY:
			result.append(entry)
			current_pos += 1
			continue
		
		# Find the last non-FRAME entry in our result
		var last_level = Logger.LogLevel.FRAME_ONLY
		for i in range(result.size() - 1, -1, -1):
			if result[i].level != Logger.LogLevel.FRAME_ONLY:
				last_level = result[i].level
				break
		
		# If we're moving to a lower priority level
		if entry.level > last_level and last_level != Logger.LogLevel.FRAME_ONLY:
			# Find next higher priority message
			var next_high_priority_pos = entries.size()
			for i in range(current_pos + 1, entries.size()):
				if entries[i].level <= last_level:
					next_high_priority_pos = i
					break
			
			# Check possible fold levels from most granular to least
			for fold_level in range(entry.level - 1, last_level, -1):
				# Look ahead to see if we have any messages at this level before next high priority
				var has_messages_at_level = false
				for look_ahead in range(current_pos + 1, next_high_priority_pos):
					if entries[look_ahead].level == fold_level:
						has_messages_at_level = true
						break
				
				# If we'll have messages at this level, add a fold point and stop checking
				if has_messages_at_level:
					print("Adding fold point at level %s for lower priority messages" % 
						  Logger.LogLevel.keys()[fold_level])
					result.append(_create_fold_point(fold_level))
					break
		
		# Add the current entry
		result.append(entry)
		current_pos += 1
	
	print("\nFinal result has %d entries (started with %d)" % [result.size(), entries.size()])
	return result

## Create a fold point entry
func _create_fold_point(level: Logger.LogLevel) -> LogEntry:
	var log = LogEntry.new(
		level,
		&"FOLD_POINT",
		"--- Fold ---",
		null
	)
	return log
