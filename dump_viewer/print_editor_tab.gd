@tool
extends Control

@onready var dump_viewer: DumpViewer = $DumpViewer


func _ready():
	# Initialize UI elements if needed
	pass


func load_latest_dump(path: String):
	dump_viewer.load_dump_file(path)
