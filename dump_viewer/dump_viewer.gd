@tool
class_name DumpViewer extends Control

enum Columns {
	TIMESTAMP = 0,
	LEVEL = 1,
	MODULE = 2,
	MESSAGE = 3
}

@onready var tree: Tree = $Tree
@onready var sidebar: VBoxContainer = $Sidebar
var print_settings: PrintSettings


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


func load_dump_file(file_path: String) -> void:
	setup_tree()  # Clear and reset the tree
	
	if not FileAccess.file_exists(file_path):
		create_error_item("Error: Could not find dump file at %s" % file_path)
		return
		
	var dumps = ErrorDump.load_dumps(file_path)
	if dumps.is_empty():
		create_error_item("Error: No valid dumps found in file")
		return
	
	var root = tree.create_item()  # Hidden root
	
	# Create a tree item for each dump
	for dump_index in range(dumps.size()):
		var dump = dumps[dump_index]
		add_dump_to_tree(dump, root, dump_index)


func add_dump_to_tree(dump: Dictionary, parent: TreeItem, dump_index: int) -> void:
	var dump_time = format_timestamp(dump.timestamp)
	var dump_item = tree.create_item(parent)
	
	# Format the dump header
	var header_text = "Dump %d (Reason: %s)" % [
		dump_index + 1,
		dump.reason
	]
	
	# Set the header across all columns
	dump_item.set_text(Columns.TIMESTAMP, dump_time)
	dump_item.set_text(Columns.MESSAGE, header_text)
	
	# Color the entire header row
	for col in range(tree.columns):
		dump_item.set_custom_color(col, Color.YELLOW)
	
	# Make the dump header expandable
	dump_item.set_collapsed(false)  # Start expanded
	
	# Add log entries for each logger
	var total_entries = 0
	for logger_id in dump.loggers:
		var logger_data = dump.loggers[logger_id]
		if not logger_data.log_history.items.is_empty():
			total_entries += add_logger_entries(logger_data, dump_item)
	
	# Update the header to show entry count
	header_text += " (%d entries)" % total_entries
	dump_item.set_text(Columns.MESSAGE, header_text)


func add_logger_entries(logger_data: Dictionary, parent: TreeItem) -> int:
	var entries_added = 0
	
	# Process each log entry
	for entry_data in logger_data.log_history.items:
		var level_idx = Logger.LogLevel.keys().find(entry_data.level)
		if level_idx == -1:
			push_warning("Invalid log level found in dump: " + entry_data.level)
			continue
		
		# Create tree item for this entry
		var entry_item = tree.create_item(parent)
		
		# Set each column's content
		entry_item.set_text(Columns.TIMESTAMP, format_time(entry_data.timestamp))
		entry_item.set_text(Columns.LEVEL, entry_data.level)
		entry_item.set_text(Columns.MODULE, entry_data.module)
		entry_item.set_text(Columns.MESSAGE, entry_data.message)
		
		# Color code based on log level
		var level_color = get_level_color(level_idx)
		entry_item.set_custom_color(Columns.LEVEL, level_color)
		
		# Color code the module name
		entry_item.set_custom_color(Columns.MODULE, print_settings.module_name_color)
		
		# Color code timestamp
		entry_item.set_custom_color(Columns.TIMESTAMP, print_settings.timestamp_color)
		
		entries_added += 1
	
	return entries_added


func create_error_item(error_message: String) -> void:
	var root = tree.create_item()
	var error_item = tree.create_item(root)
	error_item.set_text(Columns.MESSAGE, error_message)
	
	# Make error message red across all columns
	for col in range(tree.columns):
		error_item.set_custom_color(col, Color.RED)


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
