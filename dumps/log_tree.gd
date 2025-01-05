@tool
extends Tree

enum Columns {
	MODULE,
	TIMESTAMP,
	MESSAGE,
	LEVEL,
	FRAME,
}

@export var print_settings: PrintSettings
@export var collated := true
@export var collapse_level: Logger.LogLevel = Logger.LogLevel.INFO:
	set(value):
		collapse_level = value
		refresh_tree()

# Current dump data
var _current_dumps: Array[DumpData]


func load_dump_file(path: String):
	setup_tree()  # Clear and reset the tree
	
	# Load dumps using ErrorDump
	_current_dumps = ErrorDump.load_dumps(path)
	# Reverse once during loading to get newest first
	_current_dumps.reverse()
	refresh_tree()


func refresh_tree():
	# Clear existing items
	clear()
	var root = create_item()
	
	# Process each dump in the file (already in newest-first order)
	for dump_index in range(_current_dumps.size()):
		var dump = _current_dumps[dump_index]
		add_dump_to_tree(dump, root, dump_index + 1)


func setup_tree():
	clear()
	
	# Create columns for each part of the log entry
	columns = 5
	
	# Set up column properties
	set_column_title(Columns.MODULE, "Module")
	set_column_title(Columns.TIMESTAMP, "Time")
	set_column_title(Columns.LEVEL, "Level")
	set_column_title(Columns.MESSAGE, "Message")
	set_column_title(Columns.FRAME, "Frame")
	
	# Configure column sizes
	set_column_expand(Columns.FRAME, false)
	set_column_custom_minimum_width(Columns.FRAME, 40)
	
	set_column_expand(Columns.TIMESTAMP, false)
	set_column_custom_minimum_width(Columns.TIMESTAMP, 70)
	
	set_column_expand(Columns.LEVEL, false)
	set_column_custom_minimum_width(Columns.LEVEL, 110)
	
	set_column_expand(Columns.MODULE, false)
	set_column_custom_minimum_width(Columns.MODULE, 140)
	
	set_column_expand(Columns.MESSAGE, true)
	set_column_custom_minimum_width(Columns.MESSAGE, 300)
	
	# Show column titles
	set_column_titles_visible(true)
	hide_root = true


func add_dump_to_tree(dump: DumpData, parent: TreeItem, dump_index: int) -> void:
	# Create dump header
	var dump_item = create_item(parent)
	dump_item.collapsed = collapse_level == Logger.LogLevel.SILENT
	
	# Get all entries
	var entries = dump.get_all_entries(collated)
	var header = "Dump %d | %d Entries | Reason: %s" % \
			[dump_index, entries.size(), dump.metadata.reason]
	
	dump_item.set_text(Columns.TIMESTAMP, format_time(dump.metadata.timestamp))
	dump_item.set_text(Columns.MESSAGE, header)
	
	# Color the header row
	for col in range(columns):
		dump_item.set_custom_color(col, print_settings.dump_header_color)
	
	if !collated:
		# Group by module first
		var module_entries = {}
		for entry in entries:
			if not module_entries.has(entry.module):
				module_entries[entry.module] = []
			module_entries[entry.module].append(entry)
		
		# Add module groups
		for module in module_entries.keys():
			var module_item = create_item(dump_item)
			module_item.set_text(Columns.MODULE, module)
			module_item.set_text(Columns.MESSAGE, "Module History")
			add_entries_hierarchically(module_item, module_entries[module])
	else:
		# Add all entries hierarchically
		add_entries_hierarchically(dump_item, entries)


func add_entries_hierarchically(parent: TreeItem, entries: Array) -> void:
	var current_parent = parent
	var last_entry_at_level = {}  # Keep track of last entry at each level
	var entry_tree_items = {}  # Dictionary to map entries to their tree items
	
	# Process each entry
	for entry in entries:
		# Find the most appropriate parent by looking for more important levels
		var parent_entry = null
		var parent_level = entry.level - 1  # Start from one level more important
		
		# Look for the most recent entry of higher importance
		while parent_level >= Logger.LogLevel.ERROR:  # Stop at ERROR level
			if last_entry_at_level.has(parent_level):
				parent_entry = last_entry_at_level[parent_level]
				break
			parent_level -= 1  # Move to next more important level
		
		# Create the tree item under the appropriate parent
		var tree_item: TreeItem
		if parent_entry and entry_tree_items.has(parent_entry):
			tree_item = add_entry_to_tree(entry, entry_tree_items[parent_entry])
		else:
			# If no suitable parent found, add under the dump root
			tree_item = add_entry_to_tree(entry, current_parent)
		
		# Store reference to tree item for this entry
		entry_tree_items[entry] = tree_item
		last_entry_at_level[entry.level] = entry
		
		# Set collapsed state based on the collapse_level
		# Only collapse if this entry is less important than collapse_level
		tree_item.collapsed = entry.level >= collapse_level


func add_entry_to_tree(entry: LogEntry, parent: TreeItem) -> TreeItem:
	var entry_item = create_item(parent)
	
	# Set each column's content
	entry_item.set_text(Columns.FRAME, str(entry.frame_number))
	entry_item.set_text(Columns.TIMESTAMP, format_time(entry.timestamp))
	entry_item.set_text(Columns.MODULE, entry.module)
	entry_item.set_text(Columns.MESSAGE, entry.message)
	
	var level_text = str(entry.level) #Logger.LogLevel.keys()[entry.level]
	entry_item.set_text(Columns.LEVEL, level_text)
	
	# Color code based on log level
	var level_color = get_level_color(entry.level)
	entry_item.set_custom_color(Columns.LEVEL, level_color)
	
	# Color code message based on importance
	entry_item.set_custom_color(Columns.MESSAGE, get_message_color(entry.level))
	
	# Color code other columns
	entry_item.set_custom_color(Columns.MODULE, print_settings.module_name_color)
	entry_item.set_custom_color(Columns.TIMESTAMP, print_settings.timestamp_color)
	entry_item.set_custom_color(Columns.FRAME, print_settings.frame_number_color)
	
	# Set collapsed state based on the collapse_level
	entry_item.collapsed = entry.level >= collapse_level
	
	# If this entry has frame data, add it as a child
	if entry.current_frame != null:
		var frame_item = create_item(entry_item)
		frame_item.set_text(Columns.MESSAGE, entry.current_frame.format(false))
		frame_item.set_text(Columns.MODULE, "  ")  # Add some space for indentation
		
		for col in range(columns):
			frame_item.set_custom_color(col, print_settings.frame_data_color)
		
		# Frame items are only expanded when we're at FRAME_ONLY level
		frame_item.collapsed = collapse_level != Logger.LogLevel.FRAME_ONLY
	
	return entry_item


func format_time(unix_time: float) -> String:
	var datetime = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%02d:%02d:%02d" % [
		datetime.hour,
		datetime.minute,
		datetime.second
	]


func get_level_color(level: Logger.LogLevel) -> Color:
	match level:
		Logger.LogLevel.ERROR:
			return print_settings.error_color
		Logger.LogLevel.WARNING:
			return print_settings.warning_color
		Logger.LogLevel.INFO:
			return print_settings.info_color
		Logger.LogLevel.DEBUG:
			return print_settings.debug_color
		Logger.LogLevel.VERBOSE:
			return print_settings.verbose_color
		Logger.LogLevel.FRAME_ONLY:
			return Color.WHITE_SMOKE
		_:
			return Color.WHITE_SMOKE


func get_message_color(level: Logger.LogLevel) -> Color:
	match level:
		Logger.LogLevel.ERROR:
			return print_settings.error_color.darkened(0.2)  # Slightly darker for readability
		Logger.LogLevel.WARNING:
			return print_settings.warning_color.darkened(0.2)  # Slightly darker for readability
		Logger.LogLevel.FRAME_ONLY:
			return print_settings.frame_data_color
		_:
			return Color.WHITE_SMOKE
