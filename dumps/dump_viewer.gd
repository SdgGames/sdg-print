@tool
extends Control

enum Columns {
	MODULE,
	TIMESTAMP,
	MESSAGE,
	LEVEL,
	FRAME,
}

@onready var tree := $LogTree
var print_settings: PrintSettings


func _ready():
	print_settings = PrintSettings.from_project_settings()
	tree.print_settings = print_settings


func load_dump_file(path: String):
	tree.load_dump_file(path)


func _on_refresh_pressed() -> void:
	tree.refresh_tree()


func _on_collate_button_toggled(toggled_on: bool) -> void:
	tree.collated = toggled_on
	tree.refresh_tree()


func _on_collapse_pressed() -> void:
	tree.collapse_level = Logger.LogLevel.SILENT


func _on_error_pressed() -> void:
	tree.collapse_level = Logger.LogLevel.ERROR


func _on_warning_pressed() -> void:
	tree.collapse_level = Logger.LogLevel.WARNING


func _on_info_pressed() -> void:
	tree.collapse_level = Logger.LogLevel.INFO


func _on_debug_pressed() -> void:
	tree.collapse_level = Logger.LogLevel.DEBUG


func _on_verbose_pressed() -> void:
	tree.collapse_level = Logger.LogLevel.VERBOSE


func _on_expand_pressed() -> void:
	tree.collapse_level = Logger.LogLevel.FRAME_ONLY
