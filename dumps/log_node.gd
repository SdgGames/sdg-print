class_name LogNode extends RefCounted

enum NodeType {
	MODULE,     # A module header (when not collated)
	DUMP,       # A dump section header
	ENTRY,      # A regular log entry
	FOLD_POINT  # A folding marker
}

var type: NodeType
var entry: LogEntry
var children: Array[LogNode] = []
var parent: LogNode = null
var effective_fold_level: Logger.LogLevel  # The level at which this node effectively folds


func _init(type: NodeType, entry: LogEntry):
	self.type = type
	self.entry = entry
	self.effective_fold_level = entry.level if entry != null else Logger.LogLevel.FRAME_ONLY


func add_child(child: LogNode) -> void:
	children.append(child)
	child.parent = self


func _create_fold_point(level: Logger.LogLevel) -> LogNode:
	var fold_entry = LogEntry.new(
		level,
		&"FOLD_POINT",
		"--- Fold ---",
		null
	)
	return LogNode.new(NodeType.FOLD_POINT, fold_entry)


func _look_ahead_for_fold_point(entries: Array[LogEntry]) -> Logger.LogLevel:
	var highest_level = entries[0].level  # Start with first child's level
	var current_level = entry.level
	
	# Look ahead until we find an entry at our level or higher
	for test_entry in entries:
		if test_entry.level <= current_level:
			break
		highest_level = mini(highest_level, test_entry.level)  # Remember lowest number = highest priority
	
	return highest_level


func consume_entries(entries: Array[LogEntry]) -> void:
	match type:
		NodeType.MODULE, NodeType.DUMP:
			while not entries.is_empty():
				var child = LogNode.new(NodeType.ENTRY, entries[0])
				add_child(child)
				entries.pop_front()
				child.consume_entries(entries)
		
		NodeType.ENTRY, NodeType.FOLD_POINT:
			while not entries.is_empty():
				var next_entry = entries[0]
				
				# If next entry is more verbose, or same level, it might be our child
				if next_entry.level > entry.level:
					# If there's a gap of 2+ levels, do look-ahead for first child
					if next_entry.level > entry.level + 1 and children.is_empty():
						var highest_level = _look_ahead_for_fold_point(entries)
						
						# If highest level is higher priority than next entry
						if highest_level < next_entry.level:
							# Add a fold point at that level and continue processing
							var fold_node = _create_fold_point(highest_level)
							add_child(fold_node)
							fold_node.consume_entries(entries)
							continue # Continue processing remaining entries
						else:
							# Set our effective fold level to one level above next entry
							effective_fold_level = Logger.LogLevel.values()[next_entry.level - 1]
					
					var child = LogNode.new(NodeType.ENTRY, next_entry)
					add_child(child)
					entries.pop_front()
					child.consume_entries(entries)
				else:
					# Found a higher priority entry, stop consuming
					break


# Simple tree visualization
func print_levels() -> void:
	_print_levels_recursive(0)


func _print_levels_recursive(depth: int) -> void:
	var prefix = "".repeat(depth * 2)  # Two spaces per depth level
	var level_str = "-"
	if entry != null:
		level_str = Logger.LogLevel.keys()[entry.level]
		if type == NodeType.FOLD_POINT:
			level_str += " (FOLD)"
	
	print(prefix + level_str)
	for child in children:
		child._print_levels_recursive(depth + 1)

# Detailed tree inspection for debugging
func print_tree(indent: String = "") -> void:
	var level_name = "ROOT"
	if entry != null:
		level_name = Logger.LogLevel.keys()[entry.level]
	
	var fold_level = Logger.LogLevel.keys()[effective_fold_level]
	
	print("%s%s: %s (Folds at %s) - %s" % [
		indent,
		NodeType.keys()[type],
		level_name,
		fold_level,
		entry.message if entry != null else ""
	])
	
	for child in children:
		child.print_tree(indent + "  ")
