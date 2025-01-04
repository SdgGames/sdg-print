@tool
extends Control

enum Columns {
	MODULE,
	TIMESTAMP,
	MESSAGE,
	LEVEL,
	FRAME,
}

@onready var tree: Tree = $Tree
@onready var sidebar: VBoxContainer = $Scroll/Sidebar
var print_settings: PrintSettings

# Current dump data
var _current_dumps: Array[DumpData]
# Current collation state
var _collated := true


func _ready():
	print_settings = PrintSettings.from_project_settings()
	setup_tree()


func load_dump_file(path: String):
	setup_tree()  # Clear and reset the tree
	
	# Load dumps using ErrorDump
	_current_dumps = ErrorDump.load_dumps(path)
	# Reverse once during loading to get newest first
	_current_dumps.reverse()
	refresh_tree()


func refresh_tree():
	# Clear existing items
	tree.clear()
	var root = tree.create_item()
	
	# Process each dump in the file (already in newest-first order)
	for dump_index in range(_current_dumps.size()):
		var dump = _current_dumps[dump_index]
		add_dump_to_tree(dump, root, dump_index + 1)


func setup_tree():
	tree.clear()
	
	# Create columns for each part of the log entry
	tree.columns = 5
	
	# Set up column properties
	tree.set_column_title(Columns.MODULE, "Module")
	tree.set_column_title(Columns.TIMESTAMP, "Time")
	tree.set_column_title(Columns.LEVEL, "Level")
	tree.set_column_title(Columns.MESSAGE, "Message")
	tree.set_column_title(Columns.FRAME, "Frame")
	
	# Configure column sizes
	tree.set_column_expand(Columns.FRAME, false)
	tree.set_column_custom_minimum_width(Columns.FRAME, 40)
	
	tree.set_column_expand(Columns.TIMESTAMP, false)
	tree.set_column_custom_minimum_width(Columns.TIMESTAMP, 70)
	
	tree.set_column_expand(Columns.LEVEL, false)
	tree.set_column_custom_minimum_width(Columns.LEVEL, 110)
	
	tree.set_column_expand(Columns.MODULE, false)
	tree.set_column_custom_minimum_width(Columns.MODULE, 140)
	
	tree.set_column_expand(Columns.MESSAGE, true)
	tree.set_column_custom_minimum_width(Columns.MESSAGE, 300)
	
	# Show column titles
	tree.set_column_titles_visible(true)
	tree.hide_root = true


func add_entry_to_tree(entry: LogEntry, parent: TreeItem) -> void:
	var entry_item = tree.create_item(parent)
	
	# Set each column's content
	entry_item.set_text(Columns.FRAME, str(entry.frame_number))
	entry_item.set_text(Columns.TIMESTAMP, format_time(entry.timestamp))
	
	var level_text = Logger.LogLevel.keys()[entry.level]
	if level_text == "FRAME_DATA_ONLY":
		level_text = "FRAME_ONLY"
	entry_item.set_text(Columns.LEVEL, level_text)
	
	entry_item.set_text(Columns.MODULE, entry.module)
	entry_item.set_text(Columns.MESSAGE, entry.message)
	
	# Color code based on log level
	var level_color = get_level_color(entry.level)
	entry_item.set_custom_color(Columns.LEVEL, level_color)
	
	# Color code the module name and timestamp
	entry_item.set_custom_color(Columns.MODULE, print_settings.module_name_color)
	entry_item.set_custom_color(Columns.TIMESTAMP, print_settings.timestamp_color)
	entry_item.set_custom_color(Columns.FRAME, print_settings.frame_number_color)
	entry_item.collapsed = true
	
	# If this entry has frame data, add it as a child
	if entry.current_frame != null:
		var frame_item = tree.create_item(entry_item)
		frame_item.set_text(Columns.MESSAGE, entry.current_frame.format(false))
		# Indent frame data for better visibility
		frame_item.set_text(Columns.MODULE, "  ")  # Add some space for indentation
		
		for col in range(tree.columns):
			frame_item.set_custom_color(col, print_settings.frame_data_color)


func add_dump_to_tree(dump: DumpData, parent: TreeItem, dump_number: int) -> void:
	# Create dump header
	var dump_item = tree.create_item(parent)
	
	# Get all entries based on collation mode
	var entries = dump.get_all_entries(_collated)
	var header = "Dump %d | %d Entries | Reason: %s" % \
			[dump_number, entries.size(), dump.metadata.reason]
	
	dump_item.set_text(Columns.TIMESTAMP, format_time(dump.metadata.timestamp))
	dump_item.set_text(Columns.MESSAGE, header)
	
	# Color the header row
	for col in range(tree.columns):
		dump_item.set_custom_color(col, print_settings.dump_header_color)
	
	dump_item.collapsed = false
	
	# Add all entries according to current sorting mode
	for entry in entries:
		add_entry_to_tree(entry, dump_item)


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
			return Color.WHITE


func _on_refresh_pressed() -> void:
	refresh_tree()


func _on_collate_button_toggled(toggled_on: bool) -> void:
	_collated = toggled_on
	refresh_tree()
