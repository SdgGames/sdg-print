@tool
extends EditorPlugin
## Editor plugin that adds a Print tab for viewing log dumps.
##
## The Print plugin creates a new main editor tab for viewing and analyzing log dumps
## created by the Print singleton. It handles automatic loading of dump files when
## breakpoints are hit during debugging, and provides a dedicated interface for
## examining log data.
## [br][br]
## The plugin automatically registers required autoload singletons and creates the
## necessary UI elements when activated. It also manages a custom debugger plugin
## that enables automatic loading of dumps during development.

## Name of the Print singleton for autoloading
const PluginName := "Print"

## Path to the Print singleton scene
const PluginPath := "res://addons/sdg-print/print/print.tscn"

## Path to the editor tab scene for viewing dumps
const PRINT_EDITOR_TAB := preload("res://addons/sdg-print/dump_viewer/print_editor_tab.tscn")

## Icon for the Print tab in the editor
const PRINT_TAB_ICON := preload("res://addons/sdg-print/dump_viewer/print_tab_icon.svg")

## Instance of the editor tab for viewing dumps
var editor_tab: Control

## Instance of the debugger plugin for monitoring breakpoints
var debugger_plugin: DumpDebugger

## Flag to prevent multiple simultaneous dump loads
var loading_dump := false


func _enter_tree() -> void:
	# Register project settings and autoload singleton
	PrintSettings._register_settings()
	add_autoload_singleton(PluginName, PluginPath)
	
	# Create and add the dump viewer to the main editor interface
	editor_tab = PRINT_EDITOR_TAB.instantiate()
	EditorInterface.get_editor_main_screen().add_child(editor_tab)
	_make_visible(false)
	
	# Set up debugger plugin for monitoring breakpoints
	debugger_plugin = DumpDebugger.new(self)
	add_debugger_plugin(debugger_plugin)


func _exit_tree() -> void:
	# Clean up autoload singleton
	remove_autoload_singleton(PluginName)
	
	# Clean up UI elements
	editor_tab.queue_free()
	
	# Clean up debugger plugin
	remove_debugger_plugin(debugger_plugin)
	debugger_plugin = null


## Indicates this plugin adds a main editor screen.
func _has_main_screen() -> bool:
	return true


## Shows or hides the Print tab in the editor.
func _make_visible(visible: bool) -> void:
	editor_tab.visible = visible


## Returns the name displayed in the editor tab.
func _get_plugin_name() -> String:
	return "Print"


## Returns the icon displayed in the editor tab.
func _get_plugin_icon() -> Texture2D:
	return PRINT_TAB_ICON


## Loads the latest dump file and optionally focuses the Print tab.
## [br][br]
## If [param grab_focus] is true, switches to the Print tab after loading.
## Uses a delay to ensure proper UI updates when switching tabs.
func load_latest_dump(grab_focus := true) -> void:
	# Prevent multiple simultaneous loads
	if loading_dump:
		return
	
	var absolute_path = ProjectSettings.globalize_path(ErrorDump.LATEST_DUMP_PATH)
	
	if FileAccess.file_exists(absolute_path):
		loading_dump = true
		# Start the file operation
		editor_tab.load_latest_dump(absolute_path)
		
		# Wait for UI updates before switching tabs
		await get_tree().process_frame
		await get_tree().process_frame
		
		if loading_dump:
			loading_dump = false
			if grab_focus:
				_make_visible(true)
				EditorInterface.set_main_screen_editor("Print")
