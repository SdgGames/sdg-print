@tool
class_name DumpViewer extends Control

@onready var text_display = $RichTextLabel

# Cache the settings instance to avoid recreating it for each log entry
var print_settings: PrintSettings


func _ready():
	# Initialize with default settings from project settings
	print_settings = PrintSettings.from_project_settings()


func load_dump_file(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		text_display.text = "[color=red]Error: Could not find dump file at %s[/color]" % file_path
		return
		
	var dumps = ErrorDump.load_dumps(file_path)
	if dumps.is_empty():
		text_display.text = "[color=red]Error: No valid dumps found in file[/color]"
		return
	
	# Format and display all dumps
	var formatted_output = ""
	for dump in dumps:
		formatted_output += format_dump(dump) + "\n"
	
	text_display.text = formatted_output


func format_dump(dump: Dictionary) -> String:
	var output = "[color=yellow]--- Dump at %s (Reason: %s) ---[/color]\n" % [
		format_timestamp(dump.timestamp),
		dump.reason
	]
	
	print_settings.max_module_width = dump.get("module_width")
	
	# Process each logger's data
	for logger_id in dump.loggers:
		var logger_data = dump.loggers[logger_id]
		if not logger_data.log_history.items.is_empty():
			output += format_logger_entries(logger_data)
	
	return output


func format_logger_entries(logger_data: Dictionary) -> String:
	var output = ""
	
	# Process each log entry
	for entry_data in logger_data.log_history.items:
		# Create a LogEntry instance from the dictionary data
		var level_idx = Logger.LogLevel.keys().find(entry_data.level)
		if level_idx == -1:
			push_warning("Invalid log level found in dump: " + entry_data.level)
			continue
			
		var entry = LogEntry.new(
			level_idx,
			entry_data.module,
			entry_data.message
		)
		# Set the timestamp from the saved data
		entry.timestamp = entry_data.timestamp
		entry.frame_number = entry_data.frame_number
		
		# Format the entry using the standard formatting logic
		output += entry.format(print_settings) + "\n"
	
	return output


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
