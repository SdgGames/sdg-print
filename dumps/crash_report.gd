extends Control

@onready var active_dump = $"Tabs/Active Dump"


func load_latest_dump(path: String):
	active_dump.load_dump_file(path)
