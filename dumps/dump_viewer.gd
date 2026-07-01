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
@onready var collapse: Button = $Menu/Collapse
@onready var error: Button = $Menu/Error
@onready var warning: Button = $Menu/Warning
@onready var info: Button = $Menu/Info
@onready var debug: Button = $Menu/Debug
@onready var verbose: Button = $Menu/Verbose
@onready var expand: Button = $Menu/Expand
var print_settings: PrintSettings


func _ready():
	print_settings = PrintSettings.from_project_settings()
	tree.print_settings = print_settings
	
	# Style the filter buttons to match log levels
	collapse.add_theme_color_override("font_color", print_settings.dump_header_color)
	error.add_theme_color_override("font_color", print_settings.error_color)
	warning.add_theme_color_override("font_color", print_settings.warning_color)
	info.add_theme_color_override("font_color", print_settings.info_color)
	debug.add_theme_color_override("font_color", print_settings.debug_color)
	verbose.add_theme_color_override("font_color", print_settings.verbose_color)
	expand.add_theme_color_override("font_color", print_settings.frame_data_color)
	
	collapse.add_theme_color_override("font_pressed_color", print_settings.dump_header_color)
	error.add_theme_color_override("font_pressed_color", print_settings.error_color)
	warning.add_theme_color_override("font_pressed_color", print_settings.warning_color)
	info.add_theme_color_override("font_pressed_color", print_settings.info_color)
	debug.add_theme_color_override("font_pressed_color", print_settings.debug_color)
	verbose.add_theme_color_override("font_pressed_color", print_settings.verbose_color)
	expand.add_theme_color_override("font_pressed_color", print_settings.frame_data_color)


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
	if tree.collapse_level == Logger.LogLevel.FRAME_ONLY:
		tree.collapse_level = Logger.LogLevel.FRAME_ONLY + 1
	else:
		tree.collapse_level = Logger.LogLevel.FRAME_ONLY
