class_name LogNode extends RefCounted

enum NodeType {
	ROOT,       # A module header or dump session header.
	ENTRY,      # A regular log entry
	FOLD_POINT  # A folding marker
}

var type: NodeType
var entry: LogEntry
var children: Array[LogNode] = []
var effective_fold_level: Logger.LogLevel  # The level at which this node effectively folds

var _fold_level: Logger.LogLevel # The actual level of this node (equal to entry.level when entry exists)


func _init(type: NodeType, entry: LogEntry):
	self.type = type
	self.entry = entry
	
	# Set initial effective fold level based on type
	match type:
		NodeType.ROOT:
			self._fold_level = Logger.LogLevel.SILENT
		_:
			self._fold_level = Logger.LogLevel.FRAME_ONLY if entry == null else entry.level
	self.effective_fold_level = _fold_level


func add_child(child: LogNode) -> void:
	children.append(child)


func _create_fold_point(level: Logger.LogLevel) -> LogNode:
	var fold_entry = LogEntry.new(
		level,
		&"FOLD_POINT",
		"",
		null
	)
	return LogNode.new(NodeType.FOLD_POINT, fold_entry)


func _look_ahead_for_fold_point(entries: Array[LogEntry]) -> Logger.LogLevel:
	var highest_level = entries[0].level  # Start with first child's level
	var current_level = _fold_level
	
	# Look ahead until we find an entry at our level or higher
	for test_entry in entries:
		if test_entry.level <= current_level:
			break
		highest_level = mini(highest_level, test_entry.level)  # Remember lowest number = highest priority
	
	return highest_level


func consume_entries(entries: Array[LogEntry]) -> void:
	while not entries.is_empty():
		var next_entry = entries[0]
		
		# If next entry is more verbose, or same level, it might be our child
		if next_entry.level > _fold_level or type == NodeType.ROOT:
			# If there's a gap of 2+ levels, do look-ahead for first child
			if next_entry.level > _fold_level + 1 and children.is_empty():
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
