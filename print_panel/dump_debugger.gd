class_name DumpDebugger extends EditorDebuggerPlugin
## Custom debugger plugin that monitors breakpoints for dump operations.
##
## DumpDebugger connects to the editor's debugging session to detect when breakpoints
## are hit or when debugging stops. When these events occur, it notifies the Print
## plugin to check for and load any new dump files. This enables automatic loading
## of dump data during development and debugging.

## Reference to the parent Print plugin instance
var plugin_ref: EditorPlugin


func _init(plugin: EditorPlugin):
	plugin_ref = plugin


## Called when a new debug session is started.
## Connects the necessary signals to monitor breakpoints and session end.
func _setup_session(session_id: int) -> void:
	var session = get_session(session_id)
	if session:
		session.breaked.connect(_on_breaked)
		session.stopped.connect(_on_stopped)


## Called when a breakpoint is hit during debugging.
## Triggers a dump load with focus on the Print tab.
func _on_breaked(_can_debug: bool) -> void:
	plugin_ref.load_latest_dump()


## Called when the debugging session ends.
## Triggers a final dump load without focusing the Print tab.
func _on_stopped() -> void:
	plugin_ref.load_latest_dump(false)
