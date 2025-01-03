@tool
class_name DumpViewer extends Control

@onready var text_display = $RichTextLabel


func load_dump_file(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		text_display.text = "Error: Could not find dump file at %s" % file_path
		return
		
	var dumps = ErrorDump.load_dumps(file_path)
	
	text_display.text = JSON.stringify(dumps)
