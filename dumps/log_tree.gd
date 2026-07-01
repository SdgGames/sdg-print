@tool
extends Tree

enum Columns {
	LEVEL,
	MODULE,
	MESSAGE,
	SYMBOL,
	TIMESTAMP,
	FRAME,
}

@export var collated := true
@export var collapse_level: Logger.LogLevel = Logger.LogLevel.INFO:
	set(value):
		collapse_level = value
		refresh_tree()
var print_settings: PrintSettings

# Current dump data
var _current_dumps: Array[DumpData]


func load_dump_file(path: String):
	setup_tree()  # Clear and reset the tree
	
	# Load dumps using ErrorDump
	_current_dumps = ErrorDump.load_dumps(path)
	# Reverse once during loading to get newest first
	_current_dumps.reverse()
	
	refresh_tree()


func setup_tree():
	clear()
	
	# Create columns for each part of the log entry
	columns = 6
	
	# Set up column properties
	set_column_title(Columns.LEVEL, "Level")
	set_column_title(Columns.MODULE, "Module")
	set_column_title(Columns.MESSAGE, "Message")
	set_column_title(Columns.SYMBOL, "🔗")
	set_column_title(Columns.TIMESTAMP, "Time")
	set_column_title(Columns.FRAME, "Frame")
	
	# Configure column sizes
	set_column_expand(Columns.LEVEL, false)
	set_column_custom_minimum_width(Columns.LEVEL, 180)
	
	set_column_expand(Columns.MODULE, false)
	set_column_custom_minimum_width(Columns.MODULE, 120)
	
	set_column_expand(Columns.MESSAGE, true)
	set_column_custom_minimum_width(Columns.MESSAGE, 300)
	
	set_column_expand(Columns.SYMBOL, false)
	set_column_custom_minimum_width(Columns.SYMBOL, 30)
	
	set_column_expand(Columns.TIMESTAMP, false)
	set_column_custom_minimum_width(Columns.TIMESTAMP, 70)
	
	set_column_expand(Columns.FRAME, false)
	set_column_custom_minimum_width(Columns.FRAME, 60)
	
	# Show column titles
	set_column_titles_visible(true)
	hide_root = true


## Refresh the tree view from the current dumps
func refresh_tree():
	# Clear existing items
	clear()
	var root = create_item()
	
	# For each dump, get the appropriate root node and add it to the tree
	for dump in _current_dumps:
		add_node_to_tree(dump.collated_root if collated else dump.module_root, root, true)


## Recursively add a log node and its children to the tree
func add_node_to_tree(node: LogNode, parent: TreeItem, is_dump_root := false) -> void:
	var tree_item = create_item(parent)
	
	if is_dump_root:
		_setup_dump_item(tree_item, node)
	else:
		match node.type:
			LogNode.NodeType.ROOT:
				_setup_module_item(tree_item, node)
			LogNode.NodeType.ENTRY:
				_setup_entry_item(tree_item, node.entry)
			LogNode.NodeType.FOLD_POINT:
				_setup_fold_item(tree_item, node.effective_fold_level + 1)
	
	# Add all children recursively
	for child in node.children:
		add_node_to_tree(child, tree_item)
	
	# Set initial collapsed state based on level and type
	_set_item_collapsed_state(tree_item, node)


## Set up a dump header tree item
func _setup_dump_item(item: TreeItem, node: LogNode) -> void:
	item.set_text(Columns.MESSAGE, node.entry.message)
	for col in range(columns):
		item.set_custom_color(col, print_settings.dump_header_color)


## Set up a module header tree item
func _setup_module_item(item: TreeItem, node: LogNode) -> void:
	item.set_text(Columns.MODULE, node.entry.module)
	item.set_text(Columns.MESSAGE, "-- %s Module History --" % node.entry.module)
	item.set_custom_color(Columns.MODULE, print_settings.module_name_color)
	item.set_custom_color(Columns.MESSAGE, print_settings.module_name_color)


## Set up a normal log entry tree item
func _setup_entry_item(item: TreeItem, entry: LogEntry) -> void:
	item.set_text(Columns.FRAME, str(entry.frame_number))
	item.set_text(Columns.TIMESTAMP, format_time(entry.timestamp))
	item.set_text(Columns.MODULE, entry.module)
	item.set_text(Columns.MESSAGE, entry.message)
	item.set_text(Columns.LEVEL, Logger.LogLevel.keys()[entry.level])
	
	# Color code based on log level
	var level_color = get_level_color(entry.level)
	item.set_custom_color(Columns.LEVEL, level_color)
	
	# Color code message based on importance
	item.set_custom_color(Columns.MESSAGE, get_message_color(entry.level))
	
	# Color code other columns
	item.set_custom_color(Columns.MODULE, print_settings.module_name_color)
	item.set_custom_color(Columns.TIMESTAMP, print_settings.timestamp_color)
	item.set_custom_color(Columns.FRAME, print_settings.frame_number_color)
	
	# Set up frame data if present
	if entry.current_frame != null:
		# This entry is only frame data. Put the title inside the fold.
		if entry.level == Logger.LogLevel.FRAME_ONLY:
			item.set_text(Columns.SYMBOL, "⊡")
			item.set_text(Columns.TIMESTAMP, "")
			_setup_frame_data(item, entry)
		else:
			var frame_parent = create_item(item)
			item.set_text(Columns.SYMBOL, "⧉")
			frame_parent.set_text(Columns.SYMBOL, "⧉")
			frame_parent.set_text(Columns.LEVEL, "⧉ FRAME")
			frame_parent.set_custom_color(Columns.LEVEL, level_color)
			_setup_frame_data(frame_parent, entry)


## Set up an item for frame data.
func _setup_frame_data(parent: TreeItem, entry: LogEntry):
	parent.set_text(Columns.MESSAGE, entry.current_frame.title)
	parent.set_custom_color(Columns.MESSAGE, print_settings.frame_data_color)
	parent.collapsed = Logger.LogLevel.FRAME_ONLY >= collapse_level
	var frame_item = create_item(parent)
	frame_item.set_text(Columns.MESSAGE, entry.current_frame.format(false))
	frame_item.set_custom_color(Columns.MESSAGE, print_settings.frame_data_color)


## Set up a fold point tree item
func _setup_fold_item(item: TreeItem, level: int) -> void:
	item.set_text(Columns.LEVEL, "   ---")
	item.set_text(Columns.MODULE, "   ---")
	item.set_text(Columns.MESSAGE, "   ---")
	item.set_text(Columns.SYMBOL, "-")
	item.set_text(Columns.TIMESTAMP, "---")
	item.set_text(Columns.FRAME, "---")
	
	var color = get_level_color(level)
	for col in range(columns):
		item.set_custom_color(col, color)


## Determine if a tree item should be initially collapsed
func _set_item_collapsed_state(item: TreeItem, node: LogNode) -> void:
	item.collapsed = node.effective_fold_level >= collapse_level


## Format a microsecond timestamp as HH:MM:SS.mmm
func format_time(usec: int) -> String:
	var msec = usec / 1000  # Convert to milliseconds for display
	var seconds = msec / 1000
	var minutes = seconds / 60
	var hours = minutes / 60
	
	return "%02d:%02d\n%02d.%03d" % [
		hours % 24,
		minutes % 60,
		seconds % 60,
		msec % 1000
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
			return print_settings.frame_data_color
		_:
			return print_settings.default_message_color


func get_message_color(level: Logger.LogLevel) -> Color:
	match level:
		Logger.LogLevel.ERROR:
			return print_settings.error_color
		Logger.LogLevel.WARNING:
			return print_settings.warning_color
		Logger.LogLevel.FRAME_ONLY:
			return print_settings.frame_data_color
		_:
			return print_settings.default_message_color
