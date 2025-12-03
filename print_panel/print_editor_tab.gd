@tool
extends Control

@onready var active_dump = $"Tabs/Active Dump"


func load_latest_dump(path: String):
	await active_dump.load_dump_file(path)
	print("load_latest_dump - deleting: ", path)
	# todo re-enable:
	# DirAccess.remove_absolute(path)
