@tool
class_name DumpViewer extends Control

enum Columns {
	TIMESTAMP = 0,
	LEVEL = 1,
	MODULE = 2,
	MESSAGE = 3
}

@onready var tree: Tree = $Tree
@onready var sidebar: VBoxContainer = $Scroll/Sidebar
var print_settings: PrintSettings

# Current dump data
var _current_dumps: Array[DumpData]


func _ready():
	print_settings = PrintSettings.from_project_settings()
	setup_tree()


func setup_tree():
	tree.clear()
	
	# Create columns for each part of the log entry
	tree.columns = 4
	
	# Set up column properties
	tree.set_column_title(Columns.TIMESTAMP, "Time")
	tree.set_column_title(Columns.LEVEL, "Level")
	tree.set_column_title(Columns.MODULE, "Module")
	tree.set_column_title(Columns.MESSAGE, "Message")
	
	# Configure column sizes
	tree.set_column_expand(Columns.TIMESTAMP, false)  # Fixed width
	tree.set_column_custom_minimum_width(Columns.TIMESTAMP, 100)
	
	tree.set_column_expand(Columns.LEVEL, false)  # Fixed width
	tree.set_column_custom_minimum_width(Columns.LEVEL, 80)
	
	tree.set_column_expand(Columns.MODULE, false)  # Fixed width
	tree.set_column_custom_minimum_width(Columns.MODULE, 120)
	
	tree.set_column_expand(Columns.MESSAGE, true)  # Expandable
	tree.set_column_custom_minimum_width(Columns.MESSAGE, 300)
	
	# Show column titles
	tree.set_column_titles_visible(true)
	tree.hide_root = true


func load_dump_file(path: String):
	setup_tree()  # Clear and reset the tree
	
	# Load dumps using ErrorDump
	_current_dumps = ErrorDump.load_dumps(path)
	if _current_dumps.is_empty():
		create_error_item("No valid dumps found in file")
		return
	
	refresh_tree()


func refresh_tree() -> void:
	# Clear existing items
	tree.clear()
	var root = tree.create_item()
	
	if _current_dumps.is_empty():
		create_error_item("No dump data loaded")
		return
	
	# Process each dump in the file
	for dump_index in range(_current_dumps.size()):
		var dump = _current_dumps[dump_index]
		add_dump_to_tree(dump, root, dump_index)


func add_dump_to_tree(dump: DumpData, parent: TreeItem, dump_index: int) -> void:
	# Create dump header
	var dump_item = tree.create_item(parent)
	var dump_time = format_timestamp(dump.metadata.timestamp)
	
	# Get all entries chronologically
	var entries = dump.get_all_entries()
	var header_text = "Dump %d (Reason: %s, %d entries)" % [
		dump_index + 1,
		dump.metadata.reason,
		entries.size()
	]
	
	# Set header
	dump_item.set_text(Columns.TIMESTAMP, dump_time)
	dump_item.set_text(Columns.MESSAGE, header_text)
	
	# Color the header row
	for col in range(tree.columns):
		dump_item.set_custom_color(col, Color.YELLOW)
	
	dump_item.collapsed = false
	
	# Add all entries chronologically
	for entry in entries:
		add_entry_to_tree(entry, dump_item)


func add_entry_to_tree(entry: LogEntry, parent: TreeItem) -> void:
	var entry_item = tree.create_item(parent)
	
	# Set each column's content
	entry_item.set_text(Columns.TIMESTAMP, format_time(entry.timestamp))
	entry_item.set_text(Columns.LEVEL, Logger.LogLevel.keys()[entry.level])
	entry_item.set_text(Columns.MODULE, entry.module)
	entry_item.set_text(Columns.MESSAGE, entry.message)
	
	# Color code based on log level
	var level_color = get_level_color(entry.level)
	entry_item.set_custom_color(Columns.LEVEL, level_color)
	
	# Color code the module name and timestamp
	entry_item.set_custom_color(Columns.MODULE, print_settings.module_name_color)
	entry_item.set_custom_color(Columns.TIMESTAMP, print_settings.timestamp_color)
	
	# If this entry has frame data, add it as a child
	if entry.current_frame != null:
		var frame_item = tree.create_item(entry_item)
		frame_item.set_text(Columns.MESSAGE, entry.current_frame.format(false))
		# Indent frame data for better visibility
		frame_item.set_text(Columns.MODULE, "  ")  # Add some space for indentation
		
		# Use a slightly different color for frame data
		for col in range(tree.columns):
			frame_item.set_custom_color(col, print_settings.debug_color.darkened(0.2))


func create_error_item(error_message: String) -> void:
	var root = tree.create_item()
	var error_item = tree.create_item(root)
	error_item.set_text(Columns.MESSAGE, error_message)
	
	# Make error message red across all columns
	for col in range(tree.columns):
		error_item.set_custom_color(col, Color.RED)


# Helper functions for formatting
func format_timestamp(unix_time: float) -> String:
	var datetime = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		datetime.year,
		datetime.month,
		datetime.day,
		datetime.hour,
		datetime.minute,
		datetime.second
	]


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
		_:
			return Color.WHITE


# Column visibility control
func set_column_visible(column: Columns, visible: bool) -> void:
	if column >= 0 and column < tree.columns:
		# Store current widths
		var widths = []
		for i in range(tree.columns):
			widths.append(tree.get_column_width(i))
		
		if visible:
			# Restore the column's previous width
			tree.set_column_expand(column, column == Columns.MESSAGE)
			tree.set_column_custom_minimum_width(column, widths[column])
		else:
			# Hide the column by setting its width to 0
			tree.set_column_custom_minimum_width(column, 0)
			tree.set_column_expand(column, false)
