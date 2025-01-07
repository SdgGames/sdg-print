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
		log_history = RingBuffer.from_dict(data.log_history, LogEntry.from_dict.bind(id))
		frame_history = RingBuffer.from_dict(data.frame_history, LogEntry.from_dict.bind(id))
	
	
	## Get all entries.
	func get_entries(min_level := Logger.LogLevel.FRAME_ONLY) -> Array[LogEntry]:
		var entries: Array[LogEntry] = []
		
		# Add log entries that meet the minimum level
		for entry in log_history.get_all():
			if entry.level <= min_level:
				entries.append(entry)
		
		# Add frame entries
		for entry in frame_history.get_all():
			entries.append(entry)
		
		return entries

## Information about when and why this dump was created
var metadata: Dictionary
## Collection of logger data, keyed by logger ID
var loggers: Dictionary = {}
## Index of this dump in the file (set by viewer)
var dump_index: int = -1

## Get a formatted header string for this dump
var formatted_header: String:
	get:
		var datetime = Time.get_datetime_dict_from_unix_time(metadata.timestamp)
		var date_str = "%02d-%02d-%d %02d:%02d:%02d" % [
			datetime.month,
			datetime.day,
			datetime.year,
			datetime.hour,
			datetime.minute,
			datetime.second
		]
		return "Dump %d | %s | Reason: %s" % [dump_index, date_str, metadata.reason]

# Root nodes for different views
var collated_root: LogNode
var module_root: LogNode

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
	
	# Build both views
	_build_view_trees()
	
	return true


## Build the collated and module-based view trees
func _build_view_trees() -> void:
	# Create dump header entry
	var dump_header = LogEntry.new(
		Logger.LogLevel.SILENT,
		&"DUMP",
		formatted_header,
		null
	)
	
	# Build collated view
	var all_entries = _get_collated_entries()
	collated_root = LogNode.new(LogNode.NodeType.ROOT, dump_header)
	collated_root.consume_entries(all_entries)
	
	# Build module view
	module_root = LogNode.new(LogNode.NodeType.ROOT, dump_header)
	
	# Sort module IDs for consistent ordering
	var module_ids = loggers.keys()
	module_ids.sort()
	
	# Create module nodes and feed them their entries
	for module_id in module_ids:
		var logger = loggers[module_id]
		var entries = logger.get_entries()
		
		# Sort entries by timestamp, newest first
		entries.sort_custom(
			func(a: LogEntry, b: LogEntry) -> bool:
				return a.timestamp > b.timestamp
		)
		
		# Create and add module node
		var module_node = LogNode.new(
			LogNode.NodeType.ROOT,
			LogEntry.new(Logger.LogLevel.SILENT, module_id, "", null)
		)
		module_root.add_child(module_node)
		
		# Let the module node process its entries
		module_node.consume_entries(entries)


## Get all entries from all loggers in timestamp order (newest first)
func _get_collated_entries() -> Array[LogEntry]:
	var all_entries: Array[LogEntry] = []
	
	# Collect all entries
	for logger in loggers.values():
		all_entries.append_array(logger.get_entries())
	
	# Sort by timestamp, newest first
	all_entries.sort_custom(
		func(a: LogEntry, b: LogEntry) -> bool:
			return a.timestamp > b.timestamp
	)
	
	return all_entries
